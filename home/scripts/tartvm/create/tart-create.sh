#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# tart base-image staging + VM create — mac-only VM host
# Idempotent. Creates a macOS guest VM from a base image under TART_HOME.
#
# Usage:
#   tart-create.sh            # use default name/image
#   VM_NAME=win macos SONOMA_IMG=ghcr.io/cirruslabs/macos-sonoma-base:latest tart-create.sh
#   tart-create.sh --name win --image ghcr.io/cirruslabs/macos-sonoma-base:latest --cpus 4 --ram 8
#
# Mirrors winvm/env/bootstrap-win.ps1's staging approach: pull once, offline create.
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -uo pipefail

VM_NAME="${VM_NAME:-win}"
SONOMA_IMG="${SONOMA_IMG:-ghcr.io/cirruslabs/macos-sonoma-base:latest}"
CPUS="${CPUS:-4}"
RAM_GB="${RAM_GB:-8}"
DISK_GB="${DISK_GB:-40}"

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
log "    image=$SONOMA_IMG  cpus=$CPUS ram=${RAM_GB}G disk=${DISK_GB}G"

# 1) base image cached?
if tart list --format json 2>/dev/null | grep -q "\"$VM_NAME\""; then
    ok "VM '$VM_NAME' already exists — nothing to create"
    exit 0
fi

log "    ensuring base image is pulled (offline-create path)..."
if ! tart image list 2>/dev/null | grep -qi "sonoma"; then
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

# 3) create
log "    creating VM..."
if ! tart create "$VM_NAME" --from "$SONOMA_IMG" \
        --cpu "$CPUS" --memory "$RAM_GB" \
        --disk-size "$DISK_GB" 2>/dev/null; then
    die "tart create failed for '$VM_NAME'"
fi
ok "VM '$VM_NAME' created"

# 4) confirm
tart list 2>/dev/null
log "==> done. Run 'tart run $VM_NAME' or 'tart ip $VM_NAME' to boot/ssh."
