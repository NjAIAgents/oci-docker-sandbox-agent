#!/usr/bin/env bash
# 03-backup/pg-backup-cleanup.sh — Cleanup old backups when bucket exceeds size threshold
#
# Checks total size of ods-pg-backups bucket. If it exceeds CRITICAL_BYTES (18 GB),
# deletes all backup objects older than CLEANUP_DAYS (15 days) to reclaim space.
# Safe to run as a cron job — exits cleanly if size is below threshold.
#
# Usage:
#   sudo /usr/local/bin/pg-backup-cleanup.sh
#
# Cron (runs 30 min after daily backup):
#   30 2 * * * /usr/local/bin/pg-backup-cleanup.sh >> /var/log/pg-backup.log 2>&1

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BUCKET="ods-pg-backups"
NAMESPACE="axnkbbvhdv9p"
CRITICAL_BYTES=$((18 * 1024 * 1024 * 1024))   # 18 GB
CLEANUP_DAYS=15
LOG_TAG="pg-backup-cleanup"

log()  { logger -t "$LOG_TAG" "$1"; echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1"; }
fail() { log "ERROR: $1"; exit 1; }

command -v oci >/dev/null 2>&1 || fail "OCI CLI not found."

# ── Get current bucket size ───────────────────────────────────────────────────
log "Checking bucket size..."

TOTAL_BYTES=$(oci os object list \
  --auth instance_principal \
  --bucket-name "$BUCKET" \
  --namespace "$NAMESPACE" \
  --prefix "backups/" \
  --fields name,size,timeModified \
  --all \
  --output json 2>/dev/null \
  | python3 -c "
import sys, json
objects = json.load(sys.stdin).get('data', [])
print(sum(o.get('size', 0) for o in objects))
")

TOTAL_GB=$(python3 -c "print(round(${TOTAL_BYTES} / 1024 / 1024 / 1024, 2))")
log "Current bucket size: ${TOTAL_GB} GB (${TOTAL_BYTES} bytes)"

# ── Check threshold ───────────────────────────────────────────────────────────
if [ "$TOTAL_BYTES" -lt "$CRITICAL_BYTES" ]; then
  log "Below 18 GB threshold — no cleanup needed."
  exit 0
fi

log "CRITICAL threshold reached (${TOTAL_GB} GB >= 18 GB) — cleaning up backups older than ${CLEANUP_DAYS} days..."

# ── Find and delete objects older than CLEANUP_DAYS ───────────────────────────
CUTOFF=$(python3 -c "
from datetime import datetime, timezone, timedelta
cutoff = datetime.now(timezone.utc) - timedelta(days=${CLEANUP_DAYS})
print(cutoff.strftime('%Y-%m-%dT%H:%M:%S'))
")

log "Deleting backups older than ${CUTOFF} UTC..."

TO_DELETE=$(oci os object list \
  --auth instance_principal \
  --bucket-name "$BUCKET" \
  --namespace "$NAMESPACE" \
  --prefix "backups/" \
  --fields name,size,timeModified \
  --all \
  --output json 2>/dev/null \
  | python3 -c "
import sys, json
from datetime import datetime, timezone

cutoff_str = '${CUTOFF}'
cutoff = datetime.fromisoformat(cutoff_str).replace(tzinfo=timezone.utc)
objects = json.load(sys.stdin).get('data', [])
old = [o['name'] for o in objects
       if datetime.fromisoformat(o['time-modified'].replace('Z','+00:00')) < cutoff]
print('\n'.join(old))
")

if [ -z "$TO_DELETE" ]; then
  log "No backups older than ${CLEANUP_DAYS} days found. Consider reducing retention further if size remains critical."
  exit 0
fi

DELETED=0
FREED_BYTES=0

while IFS= read -r OBJECT_NAME; do
  [ -z "$OBJECT_NAME" ] && continue

  SIZE=$(oci os object head \
    --auth instance_principal \
    --bucket-name "$BUCKET" \
    --namespace "$NAMESPACE" \
    --name "$OBJECT_NAME" \
    --output json 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('content-length', 0))" || echo 0)

  oci os object delete \
    --auth instance_principal \
    --bucket-name "$BUCKET" \
    --namespace "$NAMESPACE" \
    --name "$OBJECT_NAME" \
    --force 2>/dev/null

  log "Deleted: $OBJECT_NAME (${SIZE} bytes)"
  DELETED=$((DELETED + 1))
  FREED_BYTES=$((FREED_BYTES + SIZE))
done <<< "$TO_DELETE"

FREED_GB=$(python3 -c "print(round(${FREED_BYTES} / 1024 / 1024 / 1024, 2))")
NEW_TOTAL_GB=$(python3 -c "print(round((${TOTAL_BYTES} - ${FREED_BYTES}) / 1024 / 1024 / 1024, 2))")

log "Cleanup complete: deleted ${DELETED} backup(s), freed ${FREED_GB} GB, estimated new size: ${NEW_TOTAL_GB} GB"
