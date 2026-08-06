#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Stage + bootstrap chezmoi dotfiles into a tart macOS guest — mac-only host.
# Idempotent. Mirrors winvm/env/bootstrap-win.ps1 + chezmoi-pull.ps1.
#
# tart guests are macOS, so the guest pulls the SAME dotfiles repo and runs
# chezmoi apply directly — no MinGit/.exe staging needed (unlike the Windows VM).
# `tart ssh <name> <cmd>` handles the guest auth, so there's no pinned username.
#
# Usage:
#   tart-bootstrap.sh [name]     # default guest: win
#
# Steps: ensure VM created -> boot -> wait for SSH -> copy guest-bootstrap.sh ->
# run it (installs chezmoi, places the host's age pubkey for decryption, applies).
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -uo pipefail

VM_NAME="${1:-win}"
GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s   %s\n' "${GREEN}ok:${RESET}" "$*"; }
warn() { printf '%s   %s\n' "${YELLOW}warn:${RESET}" "$*"; }
die()  { printf '%s   %s\n' "${RED}fail:${RESET}" "$*" >&2; exit 1; }

is_cmd() { command -v "$1" >/dev/null 2>&1; }

is_cmd tart || { die "tart missing"; }

# 1) ensure VM exists
if ! tart list 2>/dev/null | awk '{print $1}' | grep -qx "$VM_NAME"; then
    log "guest '$VM_NAME' missing — creating with defaults"
    "$(dirname "$0")/../create/tart-create.sh" --name "$VM_NAME" || die "create failed"
fi

# 2) ensure running
state=$(tart list 2>/dev/null | awk -v n="$VM_NAME" '$1==n{print $NF}')
if [ "$state" != "running" ]; then
    log "    booting $VM_NAME..."
    tart run "$VM_NAME" >/dev/null 2>&1 &
fi
for _i in $(seq 1 60); do
    sleep 2
    st=$(tart list 2>/dev/null | awk -v n="$VM_NAME" '$1==n{print $NF}')
    [ "$st" = "running" ] && break
done
state=$(tart list 2>/dev/null | awk -v n="$VM_NAME" '$1==n{print $NF}')
[ "$state" = "running" ] || die "guest did not boot"

# 3) wait for SSH to answer (`tart ssh` routes over the VM's own SSH)
ok "waiting for SSH on $VM_NAME..."
for _i in $(seq 1 90); do
    if tart ip "$VM_NAME" >/dev/null 2>&1; then break; fi
    sleep 2
done
tart ip "$VM_NAME" >/dev/null 2>&1 || die "no guest IP"
sleep 5   # let sshd fully come up

# 4) copy + run the guest bootstrap script via tart ssh (which authenticates itself)
GUEST_SETUP="$(dirname "$0")/tart-guest-bootstrap.sh"
cat "$GUEST_SETUP" | tart ssh "$VM_NAME" 'cat > /tmp/guest-bootstrap.sh' || die "failed to copy guest bootstrap"
tart ssh "$VM_NAME" 'chmod +x /tmp/guest-bootstrap.sh && /tmp/guest-bootstrap.sh' || die "guest bootstrap failed"
ok "guest bootstrap completed"

log "==> done. Guest dotfiles are in sync (run 'chezmoi apply' on the guest to re-apply)."