#!/usr/bin/env bash
# setup.sh — Interactive setup for OCI ARM VM provisioning
#
# Runs preflight checks, auto-detects OCI config values, fetches availability
# domains live from the OCI API, prompts for remaining config, then renders
# all Terraform templates into the target directory.
#
# Compatible with macOS (bash 3.x via Homebrew) and Linux (bash 4+).
# No Python. No PHP. Pure bash + oci cli + terraform + jq.
#
# Usage:
#   bash setup.sh
#   make provision   (from repo root, calls this)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# ============================================================
# TTY-safe color setup
# ============================================================
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

info()    { printf "${BLUE}  [INFO]${RESET}  %s\n" "$*"; }
ok()      { printf "${GREEN}  [ OK ]${RESET}  %s\n" "$*"; }
warn()    { printf "${YELLOW}  [WARN]${RESET}  %s\n" "$*"; }
fail()    { printf "${RED}  [FAIL]${RESET}  %s\n" "$*" >&2; }
section() { printf "\n${BOLD}${CYAN}==> %s${RESET}\n" "$*"; }
die()     { fail "$*"; exit 1; }

# ============================================================
# Header
# ============================================================
printf "\n"
printf "${BOLD}${CYAN}=================================================${RESET}\n"
printf "${BOLD}  OCI ARM VM Provision Setup${RESET}\n"
printf "${CYAN}  Running Autonomous Agents on OCI Free Tier${RESET}\n"
printf "${BOLD}${CYAN}  Post 1 of 6${RESET}\n"
printf "${BOLD}${CYAN}=================================================${RESET}\n"
printf "\n"

# ============================================================
# Preflight checks
# ============================================================
section "Preflight checks"

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "${cmd} found at $(command -v "$cmd")"
  else
    die "${cmd} is not installed. Install it and re-run setup.sh."
  fi
}

check_cmd terraform
check_cmd oci
check_cmd jq

OCI_CONFIG="${HOME}/.oci/config"
if [ -f "$OCI_CONFIG" ]; then
  ok "~/.oci/config found"
else
  die "~/.oci/config not found. Run 'oci setup config' to create it."
fi

# ---- Auto-detect tenancy OCID and region from ~/.oci/config ----
# Handles both KEY=VALUE and KEY = VALUE formats.
DETECTED_TENANCY=$(grep -E '^tenancy\s*=' "$OCI_CONFIG" | head -1 | sed 's/.*=\s*//' | tr -d ' \r\t')
DETECTED_REGION=$(grep  -E '^region\s*='  "$OCI_CONFIG" | head -1 | sed 's/.*=\s*//' | tr -d ' \r\t')

[ -n "$DETECTED_TENANCY" ] || die "tenancy OCID not found in ~/.oci/config. Ensure the file has a 'tenancy=' line."
[ -n "$DETECTED_REGION"  ] || die "region not found in ~/.oci/config. Ensure the file has a 'region=' line."

ok "Detected tenancy OCID: ${DETECTED_TENANCY}"
ok "Detected region:        ${DETECTED_REGION}"

# ---- Verify OCI API connectivity ----
info "Verifying OCI API connectivity (oci iam tenancy get)..."
if oci iam tenancy get --tenancy-id "$DETECTED_TENANCY" --output json >/dev/null 2>&1; then
  ok "OCI API connectivity confirmed"
else
  die "OCI API call failed. Check ~/.oci/config credentials, key_file path, and network connectivity."
fi

# ============================================================
# Interactive prompts
# ============================================================
section "Configuration"

echo ""
info "Press Enter to accept the default shown in [brackets]."
info "All values can be overridden. Defaults come from ~/.oci/config where possible."
echo ""

# prompt <label> <default>
# Prints prompt to stderr so it does not get captured in $(...).
# Reads answer from stdin. Echoes the final value to stdout.
prompt() {
  local label="$1"
  local default="$2"
  local value
  if [ -n "$default" ]; then
    printf "  ${BOLD}%s${RESET} [${CYAN}%s${RESET}]: " "$label" "$default" >&2
  else
    printf "  ${BOLD}%s${RESET}: " "$label" >&2
  fi
  read -r value
  printf "%s" "${value:-$default}"
}

# -- Target directory --
echo ""
TARGET_DIR=$(prompt "Target directory for generated files (Enter to use 01-provision/)" "")
if [ -z "$TARGET_DIR" ]; then
  TARGET_DIR="${SCRIPT_DIR}"
fi
# Expand leading ~
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
mkdir -p "$TARGET_DIR"
ok "Target directory: ${TARGET_DIR}"

# -- OCI config values --
echo ""
REGION=$(prompt         "OCI region"                              "$DETECTED_REGION")
TENANCY_OCID=$(prompt   "Tenancy OCID"                            "$DETECTED_TENANCY")
COMPARTMENT_OCID=$(prompt "Compartment OCID (default: tenancy root)" "$TENANCY_OCID")

# -- Instance sizing --
echo ""
OCPUS=$(prompt "OCPUs (1-4, Always Free total: 4)" "4")
MEM=$(prompt   "Memory GB (6/12/18/24, Always Free total: 24 GB)" "24")

# Basic numeric validation
case "$OCPUS" in
  [1-4]) ;;
  *) warn "OCPUs value '$OCPUS' is outside 1-4. Continuing, but Always Free limit is 4 total." ;;
esac
case "$MEM" in
  6|12|18|24) ;;
  *) warn "Memory value '$MEM' is non-standard (expected 6/12/18/24). Continuing." ;;
esac

# -- SSH key --
echo ""
# Auto-detect whichever key exists — ed25519 preferred, fall back to rsa
if [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
  DETECTED_SSH_KEY="${HOME}/.ssh/id_ed25519.pub"
elif [ -f "${HOME}/.ssh/id_rsa.pub" ]; then
  DETECTED_SSH_KEY="${HOME}/.ssh/id_rsa.pub"
else
  DETECTED_SSH_KEY="${HOME}/.ssh/id_ed25519.pub"
fi
SSH_KEY_PATH=$(prompt "SSH public key path" "$DETECTED_SSH_KEY")
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
[ -f "$SSH_KEY_PATH" ] || die "SSH public key not found at: ${SSH_KEY_PATH}"
ok "SSH public key found: ${SSH_KEY_PATH}"
# Read key content now — embedded as a string in terraform.tfvars.
# file() is not allowed in .tfvars files.
SSH_KEY_CONTENT=$(tr -d '\n' < "$SSH_KEY_PATH")

# -- Retry timing --
echo ""
AD_SLEEP=$(prompt "Seconds to wait between AD attempts" "60")
ROUND_SLEEP_MIN=$(prompt "Minutes to wait between full rounds (minimum 5)" "5")

# Enforce minimum 5-minute round sleep
if [ "$ROUND_SLEEP_MIN" -lt 5 ] 2>/dev/null; then
  warn "Round sleep must be at least 5 minutes. Overriding to 5."
  ROUND_SLEEP_MIN=5
fi
ROUND_SLEEP=$(( ROUND_SLEEP_MIN * 60 ))

# ============================================================
# Fetch Availability Domains from OCI API
# ============================================================
section "Fetching Availability Domains"

info "Calling: oci iam availability-domain list --compartment-id ${TENANCY_OCID}"

AD_JSON=$(oci iam availability-domain list \
  --compartment-id "$TENANCY_OCID" \
  --output json 2>/dev/null) || die "Failed to fetch availability domains. Check compartment OCID and permissions."

AD_COUNT=$(echo "$AD_JSON" | jq '.data | length')

[ "$AD_COUNT" -ge 1 ] || die "No availability domains returned. Check your OCI region and compartment OCID."

ok "Found ${AD_COUNT} availability domain(s)"

AD1=$(echo "$AD_JSON" | jq -r '.data[0].name')

if [ "$AD_COUNT" -ge 2 ]; then
  AD2=$(echo "$AD_JSON" | jq -r '.data[1].name')
else
  AD2="$AD1"
  warn "Only 1 AD found in this region. AD2 and AD3 will reuse AD1 — fewer rotation options."
fi

if [ "$AD_COUNT" -ge 3 ]; then
  AD3=$(echo "$AD_JSON" | jq -r '.data[2].name')
else
  AD3="$AD1"
fi

info "AD1: ${AD1}"
info "AD2: ${AD2}"
info "AD3: ${AD3}"

# ============================================================
# Render templates
# ============================================================
section "Generating files"

# render <template_path> <output_path>
# Substitutes all {{PLACEHOLDER}} tokens via sed.
# Uses | as delimiter so / in paths (SSH key path, region) is safe.
render() {
  local tpl="$1"
  local out="$2"

  [ -f "$tpl" ] || die "Template not found: ${tpl}"

  sed \
    -e "s|{{REGION}}|${REGION}|g" \
    -e "s|{{TENANCY_OCID}}|${TENANCY_OCID}|g" \
    -e "s|{{COMPARTMENT_OCID}}|${COMPARTMENT_OCID}|g" \
    -e "s|{{AD1}}|${AD1}|g" \
    -e "s|{{AD2}}|${AD2}|g" \
    -e "s|{{AD3}}|${AD3}|g" \
    -e "s|{{OCPUS}}|${OCPUS}|g" \
    -e "s|{{MEM}}|${MEM}|g" \
    -e "s|{{SSH_KEY_CONTENT}}|${SSH_KEY_CONTENT}|g" \
    -e "s|{{AD_SLEEP}}|${AD_SLEEP}|g" \
    -e "s|{{ROUND_SLEEP}}|${ROUND_SLEEP}|g" \
    "$tpl" > "$out"
}

# ---- Generate provision.sh ----
render "${TEMPLATES_DIR}/provision.sh.tpl"  "${TARGET_DIR}/provision.sh"
chmod +x "${TARGET_DIR}/provision.sh"
ok "Generated: provision.sh"

# ---- Generate network/ module ----
mkdir -p "${TARGET_DIR}/network"
render "${TEMPLATES_DIR}/network/main.tf.tpl"          "${TARGET_DIR}/network/main.tf"
render "${TEMPLATES_DIR}/network/variable.tf.tpl"       "${TARGET_DIR}/network/variable.tf"
render "${TEMPLATES_DIR}/network/terraform.tfvars.tpl"  "${TARGET_DIR}/network/terraform.tfvars"
ok "Generated: network/main.tf, network/variable.tf, network/terraform.tfvars"

# ---- Generate instance/ module ----
mkdir -p "${TARGET_DIR}/instance"
render "${TEMPLATES_DIR}/instance/main.tf.tpl"          "${TARGET_DIR}/instance/main.tf"
render "${TEMPLATES_DIR}/instance/variable.tf.tpl"       "${TARGET_DIR}/instance/variable.tf"
render "${TEMPLATES_DIR}/instance/terraform.tfvars.tpl"  "${TARGET_DIR}/instance/terraform.tfvars"
ok "Generated: instance/main.tf, instance/variable.tf, instance/terraform.tfvars"

# ============================================================
# Post-generation summary
# ============================================================
section "Done"

echo ""
printf "${BOLD}Files generated in:${RESET} ${TARGET_DIR}\n"
echo ""

# Print directory tree (tree if available, else ls fallback)
if command -v tree >/dev/null 2>&1; then
  tree "$TARGET_DIR" -I ".terraform|oci-provision.log|*.tfstate*"
else
  ls -la "$TARGET_DIR"
fi

echo ""
printf "${BOLD}Next steps:${RESET}\n"

echo ""
printf "  1.  cd %s\n" "$TARGET_DIR"
printf "  2.  bash provision.sh\n"
printf "\n"
printf "      provision.sh will:\n"
printf "        • terraform init + apply network/  (VCN, subnet, IGW — once)\n"
printf "        • Loop: terraform apply instance/  (rotating across ${AD_COUNT} AD(s) until capacity opens)\n"

echo ""
info "Monitor live:  tail -f ${TARGET_DIR}/oci-provision.log"
echo ""
printf "${GREEN}On success:${RESET} fill in VM_PUBLIC_IP in your .env file, then run ${BOLD}make ssh${RESET} from repo root.\n"
echo ""
