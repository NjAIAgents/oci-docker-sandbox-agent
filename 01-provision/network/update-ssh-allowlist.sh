#!/usr/bin/env bash
# update-ssh-allowlist.sh — Restrict SSH ingress to current public IP
#
# Run this whenever your public IP changes.
# Fetches current IP via ipify, then applies the network security list.
#
# Usage: bash update-ssh-allowlist.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MY_IP=$(curl -s https://api.ipify.org)
echo "Current public IP: ${MY_IP}/32"
echo "Updating OCI security list SSH rule..."

terraform init -upgrade -reconfigure
terraform apply -auto-approve \
  -var "tenancy_ocid=$(grep tenancy_ocid ~/.oci/config | head -1 | cut -d= -f2 | tr -d ' ')"

echo ""
echo "Done. SSH access is now restricted to ${MY_IP}/32."
