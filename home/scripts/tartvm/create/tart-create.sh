#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# tart base-image staging + VM create — mac-only VM host
# Idempotent. Clones a macOS guest VM from an OCI image under TART_HOME.
#
# Usage:
#   tart-create.sh            # use default name/image
#   VM_NAME=win SONOMA_IMG=ghcr.io/cirruslabs/macos-sonoma-base:latest tart-create.sh
#   tart-create.sh --name win --image ghcr.io/cirruslabs/macos-sonoma-base:latest --cpus 4 --ram 8 --disk 60
#
# Mirrors winvm/env/bootstrap-win.ps1's staging approach: pull once, offline clone.
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -euo pipefail

VM_NAME="${VM_NAME:-win}"
SONOMA_IMG="${SONOMA_IMG:-ghcr.io/cirruslabs/macos-sonoma-base:latest}"
CPUS="${CPUS:-4}"
RAM_GB="${RAM_GB:-8}"
DISK_GB="${DISK_GB:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)  VM_NAME="$2"; shift 2 ;;
        --image) SONOMA_IMG="$2"; shift 2 ;;
        --cpus)  CPUS="$2"; shift 2 ;;
        --ram)   RAM_GB="$2"; shift 2 ;;
        --disk)  DISK_GB="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s   %s\n' "${GREEN}ok:${RESET}" "$*"; }
warn() { printf '%s   %s\n' "${YELLOW}warn:${RESET}" "$*"; }
die()  { printf '%s   %s\n' "${RED}fail:${RESET}" "$*" >&2; exit 1; }

is_cmd() { command -v "$1" >/dev/null 2>&1; }

# tart must exist and TART_HOME must resolve (shells set it; fallback for crons)
if ! is_cmd tart; then
    die "tart not found — run 'brew install openai/tools/tart' or the chezmoi run_onchange tart setup first"
fi
TH="${TART_HOME:-$HOME/.tart}"
export TART_HOME="$TH"

log "==> tart VM create ($VM_NAME)"
log "    TART_HOME=$TH"
log "    image=$SONOMA_IMG  cpus=$CPUS ram=${RAM_GB}G${DISK_GB:+ disk=${DISK_GB}G}"

# 1) guest already exists?
if tart list --source local --quiet 2>/dev/null | grep -Fqx "$VM_NAME"; then
    ok "VM '$VM_NAME' already exists — nothing to create"
    exit 0
fi

log "    ensuring base image is pulled (offline-clone path)..."
if ! tart list --source oci --quiet 2>/dev/null | grep -Fqx "$SONOMA_IMG"; then
    tart pull "$SONOMA_IMG" || die "image pull failed — check network + Virtualization.framework"
    ok "base image pulled"
else
    ok "base image already cached"
fi

# 2) space guard (mirror run_onchange tart setup)
SAFE_GB=60
avail_gb=$(df -Pk "$TH" 2>/dev/null | awk 'NR==2{printf "%.0f", $4/1024/1024}')
avail_gb=${avail_gb:-0}
if [[ "$TH" != /Volumes/External/* && avail_gb -lt SAFE_GB ]]; then
    die "$TH has only ${avail_gb}G free; need >= ${SAFE_GB}G. Mount /Volumes/External."
fi

# 3) clone and configure. Tart 2.x configures cloned VMs with `tart set`;
# `tart create --from/--cpu/--memory` is not a supported CLI.
[[ "$CPUS" =~ ^[1-9][0-9]*$ ]] || die "invalid CPU count: $CPUS"
[[ "$RAM_GB" =~ ^[1-9][0-9]*$ ]] || die "invalid RAM size: $RAM_GB"
[[ -z "$DISK_GB" || "$DISK_GB" =~ ^[1-9][0-9]*$ ]] || die "invalid disk size: $DISK_GB"

log "    cloning VM..."
created=0
cleanup_failed_clone() {
    local status=$?
    trap - EXIT
    if (( status != 0 && created == 1 )); then
        warn "configuration failed — deleting incomplete VM '$VM_NAME'"
        tart delete "$VM_NAME" >/dev/null 2>&1 || true
    fi
    exit "$status"
}
trap cleanup_failed_clone EXIT
tart clone "$SONOMA_IMG" "$VM_NAME" || die "tart clone failed for '$VM_NAME'"
created=1
tart set "$VM_NAME" --cpu "$CPUS" --memory "$((RAM_GB * 1024))" \
    || die "failed to configure CPU/RAM for '$VM_NAME'"
if [[ -n "$DISK_GB" ]]; then
    tart set "$VM_NAME" --disk-size "$DISK_GB" \
        || die "failed to grow '$VM_NAME' disk to ${DISK_GB}G (Tart cannot shrink disks)"
fi
created=0
trap - EXIT
ok "VM '$VM_NAME' created"

# 4) confirm
tart list --source local 2>/dev/null
log "==> done. Run 'tart run --no-graphics $VM_NAME'; use 'tart exec $VM_NAME ...' for commands."
