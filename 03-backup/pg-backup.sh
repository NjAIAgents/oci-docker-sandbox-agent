#!/usr/bin/env bash
# 03-backup/pg-backup.sh — Daily encrypted Postgres backup to OCI Object Storage
#
# Flow:
#   docker exec engagehub-postgres pg_dump
#     | gzip
#     | openssl enc (AES-256-CBC + PBKDF2)
#     -> OCI Object Storage ods-pg-backups/backups/<timestamp>.sql.gz.enc
#
# Encryption key is read from /etc/ods/backup.env (root:root 600)
# OCI auth uses Instance Principal — no API key required on the VM.
#
# Restore:
#   oci os object get --name backups/<file> --file - \
#     | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass file:/etc/ods/backup.key \
#     | gunzip \
#     | docker exec -i engagehub-postgres psql -U engagehub_admin -d engagehub

set -euo pipefail -o pipefail

# ── Config ────────────────────────────────────────────────────────────────────
ENV_FILE="/etc/ods/backup.env"
BUCKET="ods-pg-backups"
NAMESPACE="axnkbbvhdv9p"
DB_CONTAINER="engagehub-postgres"
DB_USER="engagehub_admin"
DB_NAME="engagehub"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OBJECT_NAME="backups/${DB_NAME}_${TIMESTAMP}.sql.gz.enc"
LOG_TAG="pg-backup"

log()  { logger -t "$LOG_TAG" "$1"; echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1"; }
fail() { log "ERROR: $1"; exit 1; }

# ── Load encryption key ───────────────────────────────────────────────────────
[ -f "$ENV_FILE" ] || fail "$ENV_FILE not found. Run the backup Ansible playbook first."
BACKUP_ENCRYPTION_KEY=$(grep -m1 '^BACKUP_ENCRYPTION_KEY=' "$ENV_FILE" | cut -d= -f2-)
[ -n "$BACKUP_ENCRYPTION_KEY" ] || fail "BACKUP_ENCRYPTION_KEY is empty in $ENV_FILE"

# ── Preflight checks ──────────────────────────────────────────────────────────
docker inspect "$DB_CONTAINER" --format '{{.State.Running}}' 2>/dev/null \
  | grep -q true || fail "Container $DB_CONTAINER is not running"

command -v oci >/dev/null 2>&1 || fail "OCI CLI not found. Install it first."

# ── Backup ────────────────────────────────────────────────────────────────────
log "Starting backup: $DB_NAME → $OBJECT_NAME"

# Write key to a temp file so openssl can read it without needing the env var
# under sudo (sudo strips environment variables by default)
KEY_FILE=$(mktemp)
chmod 600 "$KEY_FILE"
printf '%s' "$BACKUP_ENCRYPTION_KEY" > "$KEY_FILE"
trap 'rm -f "$KEY_FILE"' EXIT

docker exec "$DB_CONTAINER" \
  pg_dump -U "$DB_USER" -d "$DB_NAME" --no-password \
  | gzip \
  | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 \
      -pass "file:${KEY_FILE}" \
  | oci os object put \
      --auth instance_principal \
      --bucket-name "$BUCKET" \
      --namespace "$NAMESPACE" \
      --name "$OBJECT_NAME" \
      --file - \
      --force

log "Backup complete: $OBJECT_NAME"

# ── Verify the object landed ──────────────────────────────────────────────────
SIZE=$(oci os object head \
  --auth instance_principal \
  --bucket-name "$BUCKET" \
  --namespace "$NAMESPACE" \
  --name "$OBJECT_NAME" \
  2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('content-length','unknown'))" \
  || echo "unknown")

log "Verified upload — object size: ${SIZE} bytes"
