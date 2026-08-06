#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# tart VM maintenance — mac-only host. Idempotent.
# Encapsulates the tart equivalents of winvm/maintenance/vm-trim.ps1:
#   budget <n>   prune VM snapshots to keep budget (default: keep newest 3)
#   reclaim      reclaim free space from base images (tart prune advertised images)
#   snapshot NAME -n LABEL   create a snapshot (mirrors winvm backup point)
#   list         show VMs + snapshots
#
# All ops run through `tart` so the external-drive/TART_HOME policy is inherited.
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -uo pipefail

CMD="${1:-list}"
GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s   %s\n' "${GREEN}ok:${RESET}" "$*"; }
die()  { printf '%s   %s\n' "${RED}fail:${RESET}" "$*" >&2; exit 1; }
is_cmd() { command -v "$1" >/dev/null 2>&1; }

is_cmd tart || die "tart missing"

case "$CMD" in
    list)
        log "==> VMs:"
        tart list 2>/dev/null
        log "==> Snapshots (per VM):"
        tart list 2>/dev/null | awk '{print $1}' | grep -v '^$' | while read -r v; do
            snap=$(tart snapshot "$v" --list 2>/dev/null)
            [ -n "$snap" ] && { log "  $v:"; snap | sed 's/^/    /'; }
        done
        exit 0
        ;;
    budget)
        KEEP="${2:-6}"
        tart list 2>/dev/null | awk '{print $1}' | grep -v '^$' | while read -r v; do
            tart snapshot "$v" --list 2>/dev/null \
            | tail -n +2 | head -n -"$KEEP" | while read -r snap; do
                log "  pruning $v@$snap"
                tart snapshot "$v" --delete "$snap" 2>/dev/null
            done
        done
        ok "snapshot budget applied (keep newest $KEEP)"
        ;;
    snapshot)
        NAME="${2:?usage: tart-maint.sh snapshot <name>}"
        tart snapshot "$NAME" --create "$(date +%Y%m%d-%H%M%S)" 2>/dev/null && ok "snapshot of $NAME created"
        ;;
    prune)
        if tart image prune 2>/dev/null; then
            ok "pruned advertised/untagged base images"
        else
            die "prune failed"
        fi
        ;;
    *)
        die "unknown cmd: $CMD (list|budget|snapshot|prune)"
        ;;
esac