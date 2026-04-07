#!/usr/bin/env bash
# 02-harden/setup.sh — run the hardening playbook against your OCI VM
#
# Usage: bash 02-harden/setup.sh
# Or:    make harden
#
# Reads .env from repo root for VM_PUBLIC_IP, VM_SSH_KEY, ODS_SSH_KEY.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
INVENTORY="${SCRIPT_DIR}/inventory.ini"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

log() { echo -e "${1}${2}${RESET}"; }

# ── Preflight ────────────────────────────────────────────────────────────────
log "$BOLD" "Post 2 — OS Hardening"
echo ""

if ! command -v ansible-playbook >/dev/null 2>&1; then
  log "$RED" "[MISSING] ansible-playbook not found."
  echo ""
  echo "  Install Ansible:"
  echo "    macOS:  brew install ansible"
  echo "    Linux:  pip3 install ansible"
  echo ""
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  log "$RED" "[MISSING] .env not found at ${ENV_FILE}"
  echo ""
  echo "  Copy and fill in the template:"
  echo "    cp .env.example .env"
  echo ""
  exit 1
fi

# Load .env
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [ -z "${VM_PUBLIC_IP:-}" ]; then
  log "$RED" "[MISSING] VM_PUBLIC_IP is not set in .env"
  echo ""
  echo "  Fill in VM_PUBLIC_IP with your OCI instance's public IP."
  echo "  Find it in: OCI Console → Compute → Instances → ods-instance"
  echo ""
  exit 1
fi

if [ -z "${VM_SSH_KEY:-}" ]; then
  log "$RED" "[MISSING] VM_SSH_KEY is not set in .env"
  exit 1
fi

# Expand ~ in key paths
VM_SSH_KEY="${VM_SSH_KEY/#\~/$HOME}"
ODS_SSH_KEY="${ODS_SSH_KEY:-$VM_SSH_KEY}"
ODS_SSH_KEY="${ODS_SSH_KEY/#\~/$HOME}"

if [ ! -f "$VM_SSH_KEY" ]; then
  log "$RED" "[MISSING] SSH key not found: ${VM_SSH_KEY}"
  exit 1
fi

# Derive public key path from private key
if [ -f "${ODS_SSH_KEY}.pub" ]; then
  ODS_SSH_KEY_PUB="${ODS_SSH_KEY}.pub"
elif [ -f "${VM_SSH_KEY%.pem}.pub" ]; then
  ODS_SSH_KEY_PUB="${VM_SSH_KEY%.pem}.pub"
else
  # Try common locations
  ODS_SSH_KEY_PUB=""
  for candidate in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
    if [ -f "$candidate" ]; then
      ODS_SSH_KEY_PUB="$candidate"
      break
    fi
  done
fi

if [ -z "$ODS_SSH_KEY_PUB" ] || [ ! -f "$ODS_SSH_KEY_PUB" ]; then
  log "$RED" "[MISSING] SSH public key not found."
  echo ""
  echo "  Set ODS_SSH_KEY in .env pointing to your private key,"
  echo "  and ensure the .pub file exists alongside it."
  echo ""
  exit 1
fi

log "$GREEN" "[OK] VM_PUBLIC_IP = ${VM_PUBLIC_IP}"
log "$GREEN" "[OK] VM_SSH_KEY   = ${VM_SSH_KEY}"
log "$GREEN" "[OK] ODS_SSH_KEY  = ${ODS_SSH_KEY_PUB}"
echo ""

# ── Generate inventory ────────────────────────────────────────────────────────
log "$BLUE" "Generating inventory.ini..."
cat > "$INVENTORY" <<EOF
[ods_vm]
oci-vm ansible_host=${VM_PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${VM_SSH_KEY}
EOF
log "$GREEN" "[OK] inventory.ini written"
echo ""

# ── Run playbook ──────────────────────────────────────────────────────────────
log "$BOLD" "Running hardening playbook..."
echo ""

export ODS_SSH_KEY="$ODS_SSH_KEY_PUB"
export VM_SSH_KEY

ansible-playbook \
  -i "$INVENTORY" \
  --extra-vars "ssh_public_key_path=${ODS_SSH_KEY_PUB}" \
  "${SCRIPT_DIR}/harden.yml"

PLAYBOOK_EXIT=$?

if [ $PLAYBOOK_EXIT -ne 0 ]; then
  echo ""
  log "$RED" "Playbook failed. Check output above."
  exit $PLAYBOOK_EXIT
fi

# ── Verify ods user SSH ───────────────────────────────────────────────────────
echo ""
log "$BLUE" "Verifying ods user SSH access..."

if ssh -o StrictHostKeyChecking=no \
       -o ConnectTimeout=10 \
       -i "$ODS_SSH_KEY" \
       "ods@${VM_PUBLIC_IP}" \
       'echo ods-login-ok' 2>/dev/null | grep -q "ods-login-ok"; then
  log "$GREEN" "[OK] SSH as ods@${VM_PUBLIC_IP} works"
else
  log "$YELLOW" "[WARN] Could not verify ods SSH — check manually:"
  echo "  ssh ods@${VM_PUBLIC_IP}"
fi

echo ""
log "$GREEN" "================================================"
log "$GREEN" "  Hardening complete"
log "$GREEN" "  Connect: ssh ods@${VM_PUBLIC_IP}"
log "$GREEN" "================================================"
echo ""
echo "  Next: Post 3 — Docker sandbox"
echo "    git pull && make docker"
echo ""
