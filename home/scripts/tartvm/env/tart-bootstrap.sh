#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Stage + bootstrap chezmoi dotfiles into a tart macOS guest — mac-only host.
# Idempotent. Mirrors winvm/env/bootstrap-win.ps1 + chezmoi-pull.ps1.
#
# tart guests are macOS, so the guest pulls the SAME dotfiles repo and runs
# chezmoi apply directly — no MinGit/.exe staging needed (unlike the Windows VM).
# `tart exec <name> <cmd>` uses the guest agent, so there is no SSH dependency.
#
# Usage:
#   tart-bootstrap.sh [name]     # default guest: win
#
# Steps: ensure VM created -> boot -> wait for guest agent -> transfer the host's
# chezmoi deploy key + age identity over the private guest-agent channel ->
# copy/run guest bootstrap.
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -euo pipefail

VM_NAME="${1:-win}"
GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s   %s\n' "${GREEN}ok:${RESET}" "$*"; }
warn() { printf '%s   %s\n' "${YELLOW}warn:${RESET}" "$*"; }
die()  { printf '%s   %s\n' "${RED}fail:${RESET}" "$*" >&2; exit 1; }

is_cmd() { command -v "$1" >/dev/null 2>&1; }

vm_state() {
    tart get "$VM_NAME" --format json 2>/dev/null \
        | /usr/bin/plutil -extract State raw -o - - 2>/dev/null
}

is_cmd tart || { die "tart missing"; }
HOST_AGE_IDENTITY="${TART_AGE_IDENTITY:-$HOME/.config/chezmoi/age-key.txt}"
HOST_CHEZMOI_DEPLOY_KEY="${TART_CHEZMOI_DEPLOY_KEY:-$HOME/.ssh/id_chezmoi}"
[[ -r "$HOST_AGE_IDENTITY" ]] \
    || die "host age identity missing: $HOST_AGE_IDENTITY (set TART_AGE_IDENTITY to override)"
[[ -r "$HOST_CHEZMOI_DEPLOY_KEY" ]] \
    || die "chezmoi deploy key missing: $HOST_CHEZMOI_DEPLOY_KEY (set TART_CHEZMOI_DEPLOY_KEY to override)"

# 1) ensure VM exists
if ! tart list --source local --quiet 2>/dev/null | grep -Fqx "$VM_NAME"; then
    log "guest '$VM_NAME' missing — creating with defaults"
    "$(dirname "$0")/../create/tart-create.sh" --name "$VM_NAME" || die "create failed"
fi

# 2) ensure running
state=$(vm_state)
if [ "$state" != "running" ]; then
    log "    booting $VM_NAME..."
    tart run --no-graphics "$VM_NAME" >/dev/null 2>&1 &
fi
for ((i = 0; i < 60; i++)); do
    sleep 2
    st=$(vm_state)
    [ "$st" = "running" ] && break
done
state=$(vm_state)
[ "$state" = "running" ] || die "guest did not boot"

# 3) wait for the Tart guest agent. Base images need not expose Remote Login.
ok "waiting for guest agent on $VM_NAME..."
for ((i = 0; i < 90; i++)); do
    if tart exec "$VM_NAME" /usr/bin/true >/dev/null 2>&1; then break; fi
    sleep 2
done
tart exec "$VM_NAME" /usr/bin/true >/dev/null 2>&1 || die "guest agent unavailable"

# 4) Seed the repository deploy key and the private age identity. These are
# deliberate secret transfers to the local VM, carried over Virtualization.framework's
# guest-agent channel rather than SSH or a shared on-disk directory.
# shellcheck disable=SC2016  # $HOME must expand inside the guest, not on the host
cat "$HOST_CHEZMOI_DEPLOY_KEY" | tart exec -i "$VM_NAME" /bin/sh -c \
    'umask 077; mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"; cat > "$HOME/.ssh/id_chezmoi"; chmod 600 "$HOME/.ssh/id_chezmoi"' \
    || die "failed to transfer the chezmoi deploy key"
# shellcheck disable=SC2016  # $HOME must expand inside the guest, not on the host
cat "$HOST_AGE_IDENTITY" | tart exec -i "$VM_NAME" /bin/sh -c \
    'umask 077; mkdir -p "$HOME/.config/chezmoi"; cat > "$HOME/.config/chezmoi/age-key.txt"' \
    || die "failed to transfer the age identity"

# 5) copy + run the guest bootstrap script via the guest agent.
GUEST_SETUP="$(dirname "$0")/tart-guest-bootstrap.sh"
cat "$GUEST_SETUP" | tart exec -i "$VM_NAME" /bin/sh -c 'cat > /tmp/guest-bootstrap.sh' || die "failed to copy guest bootstrap"
tart exec "$VM_NAME" /bin/sh -c 'chmod +x /tmp/guest-bootstrap.sh && /tmp/guest-bootstrap.sh' || die "guest bootstrap failed"
ok "guest bootstrap completed"

log "==> done. Guest dotfiles are in sync (run 'chezmoi apply' on the guest to re-apply)."
