#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Verify the tart VM host + the `win` guest — mac-only.
# Idempotent health check, mirrors winvm/verify/final-check.ps1.
#   tart-verify.sh [name]      # default guest name: win
# Exits non-zero on any failed check so it can gate other steps.
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -uo pipefail

VM_NAME="${1:-win}"
GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s   %s\n' "${GREEN}ok:${RESET}" "$*"; }
warn() { printf '%s   %s\n' "${YELLOW}warn:${RESET}" "$*"; }
die()  { printf '%s   %s\n' "${RED}fail:${RESET}" "$*" >&2; }

FAIL=0
is_cmd() { command -v "$1" >/dev/null 2>&1; }

log "==> tart verify (guest: $VM_NAME)"

# 1) binary + version
if is_cmd tart; then
    ok "tart: $(tart --version 2>/dev/null | head -1)"
else
    die "tart missing"; FAIL=1
fi

# 2) TART_HOME resolves + is on external when mounted
TH="${TART_HOME:-$HOME/.tart}"
if [[ -n "$TH" ]]; then
    if [[ -d "$TH" ]]; then ok "TART_HOME exists: $TH"; else die "TART_HOME missing: $TH"; FAIL=1; fi
else
    die "TART_HOME not set"; FAIL=1
fi

# 3) base image cached (so create is offline-capable)
if tart list --source oci --quiet 2>/dev/null | grep -q .; then
    ok "base image cached"
else
    warn "no base image cached yet — VM create will need network"
fi

# 4) guest state. `tart list` includes a Source column in Tart 2.35, so use the
# structured per-VM output rather than depending on table columns.
state=""
if tart list --source local --quiet 2>/dev/null | grep -Fqx "$VM_NAME"; then
    state=$(tart get "$VM_NAME" --format json 2>/dev/null \
        | /usr/bin/plutil -extract State raw -o - - 2>/dev/null)
    ok "guest '$VM_NAME' state: $state"
else
    die "guest '$VM_NAME' not found — run tart-create.sh"
    FAIL=1
fi

# 5) boot-time pediphs if running
if [ "$state" = "running" ]; then
    ip=$(tart ip "$VM_NAME" 2>/dev/null)
    log "    guest ip: ${ip:-unavailable}"
fi

if [ "$FAIL" -eq 0 ]; then
    ok "all checks passed"
    exit 0
else
    log "one or more checks failed"
    exit 1
fi
