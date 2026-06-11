#!/usr/bin/env bash
# 03-backup/pg-restore.sh — Restore encrypted Postgres backup from OCI Object Storage
#
# Usage:
#   sudo /usr/local/bin/pg-restore.sh                         # restores latest backup
#   sudo /usr/local/bin/pg-restore.sh <object-name>           # restores specific backup
#
# Example:
#   sudo /usr/local/bin/pg-restore.sh backups/engagehub_20260611_212450.sql.gz.enc
#
# What it does:
#   1. Lists available backups (or uses the one you specify)
#   2. Downloads from OCI Object Storage
#   3. Decrypts with AES-256-CBC using key from /etc/ods/backup.env
#   4. Decompresses and restores into the running engagehub-postgres container
#
# WARNING: This DROPS and RECREATES the engagehub database. All current data
#          will be replaced by the backup. There is no undo.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
ENV_FILE="/etc/ods/backup.env"
BUCKET="ods-pg-backups"
NAMESPACE="axnkbbvhdv9p"
DB_CONTAINER="engagehub-postgres"
DB_USER="engagehub_admin"
DB_NAME="engagehub"
LOG_TAG="pg-restore"

log()  { logger -t "$LOG_TAG" "$1"; echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1"; }
fail() { log "ERROR: $1"; exit 1; }

# ── Load encryption key ───────────────────────────────────────────────────────
[ -f "$ENV_FILE" ] || fail "$ENV_FILE not found. Cannot decrypt backup without the key."
BACKUP_ENCRYPTION_KEY=$(grep -m1 '^BACKUP_ENCRYPTION_KEY=' "$ENV_FILE" | cut -d= -f2-)
[ -n "$BACKUP_ENCRYPTION_KEY" ] || fail "BACKUP_ENCRYPTION_KEY is empty in $ENV_FILE"

# ── Preflight ─────────────────────────────────────────────────────────────────
docker inspect "$DB_CONTAINER" --format '{{.State.Running}}' 2>/dev/null \
  | grep -q true || fail "Container $DB_CONTAINER is not running"

command -v oci >/dev/null 2>&1 || fail "OCI CLI not found."

# ── Select backup object ──────────────────────────────────────────────────────
if [ -n "${1:-}" ]; then
  OBJECT_NAME="$1"
  log "Using specified backup: $OBJECT_NAME"
else
  log "No backup specified — finding latest..."
  OBJECT_NAME=$(oci os object list \
    --auth instance_principal \
    --bucket-name "$BUCKET" \
    --namespace "$NAMESPACE" \
    --prefix "backups/" \
    --output json 2>/dev/null \
    | python3 -c "
import sys, json
objects = json.load(sys.stdin).get('data', [])
if not objects:
    print('')
else:
    latest = sorted(objects, key=lambda o: o['time-modified'])[-1]
    print(latest['name'])
")
  [ -n "$OBJECT_NAME" ] || fail "No backups found in bucket $BUCKET"
  log "Latest backup: $OBJECT_NAME"
fi

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │  WARNING: This will DROP and RECREATE the database  │"
echo "  │                                                      │"
echo "  │  Backup : $OBJECT_NAME"
echo "  │  Target : $DB_NAME @ $DB_CONTAINER                  │"
echo "  │                                                      │"
echo "  │  All current data will be replaced. No undo.        │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""
read -r -p "Type YES to continue: " CONFIRM
[ "$CONFIRM" = "YES" ] || { echo "Aborted."; exit 0; }

# ── Write key to temp file ────────────────────────────────────────────────────
KEY_FILE=$(mktemp)
chmod 600 "$KEY_FILE"
printf '%s' "$BACKUP_ENCRYPTION_KEY" > "$KEY_FILE"
trap 'rm -f "$KEY_FILE"' EXIT

# ── Drop and recreate database ────────────────────────────────────────────────
log "Dropping existing database $DB_NAME..."
docker exec "$DB_CONTAINER" \
  psql -U "$DB_USER" -d postgres \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" \
  > /dev/null

docker exec "$DB_CONTAINER" \
  psql -U "$DB_USER" -d postgres \
  -c "DROP DATABASE IF EXISTS $DB_NAME;" \
  > /dev/null

docker exec "$DB_CONTAINER" \
  psql -U "$DB_USER" -d postgres \
  -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" \
  > /dev/null

log "Database $DB_NAME recreated."

# ── Download, decrypt, restore ────────────────────────────────────────────────
log "Restoring from $OBJECT_NAME..."

oci os object get \
  --auth instance_principal \
  --bucket-name "$BUCKET" \
  --namespace "$NAMESPACE" \
  --name "$OBJECT_NAME" \
  --file - 2>/dev/null \
  | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
      -pass "file:${KEY_FILE}" \
  | gunzip \
  | docker exec -i "$DB_CONTAINER" \
      psql -U "$DB_USER" -d "$DB_NAME" -q

log "Restore complete: $DB_NAME restored from $OBJECT_NAME"
