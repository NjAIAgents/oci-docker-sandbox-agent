#!/usr/bin/env bash
# ssh-to-vm.sh — SSH into the provisioned OCI ARM VM
# Called by `make ssh` from repo root.
#
# Reads VM_PUBLIC_IP and VM_SSH_KEY from .env if present,
# then opens an SSH session to ubuntu@<VM_PUBLIC_IP>.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  set -o allexport
  # Read only non-comment, non-empty lines to avoid sourcing broken syntax
  while IFS= read -r line; do
    case "$line" in
      ''|'#'*) continue ;;
      *) eval "export $line" 2>/dev/null || true ;;
    esac
  done < "$ENV_FILE"
  set +o allexport
fi

VM_PUBLIC_IP="${VM_PUBLIC_IP:-}"
VM_SSH_KEY="${VM_SSH_KEY:-${HOME}/.ssh/id_rsa}"

if [ -z "$VM_PUBLIC_IP" ]; then
  echo ""
  echo "  VM_PUBLIC_IP is not set."
  echo ""
  echo "  After provision.sh completes successfully, copy .env.example to .env"
  echo "  and fill in VM_PUBLIC_IP with the IP address from terraform output."
  echo ""
  echo "  Quick steps:"
  echo "    cp .env.example .env"
  echo "    # Edit .env and set VM_PUBLIC_IP=<your IP>"
  echo "    make ssh"
  echo ""
  exit 1
fi

# Expand ~ in key path
VM_SSH_KEY="${VM_SSH_KEY/#\~/$HOME}"

echo "Connecting to ubuntu@${VM_PUBLIC_IP} using key ${VM_SSH_KEY}"
echo ""

exec ssh \
  -i "$VM_SSH_KEY" \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 \
  "ubuntu@${VM_PUBLIC_IP}"
