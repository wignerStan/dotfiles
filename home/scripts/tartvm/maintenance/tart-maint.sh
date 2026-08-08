#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# tart VM maintenance — mac-only host. Idempotent.
# Encapsulates the supported Tart 2.x maintenance operations:
#   list                  show local VMs and their configuration
#   prune [days]          prune OCI/IPSW cache entries older than N days
#   prune-vms [days]      prune local VMs older than N days (explicit/destructive)
#
# All ops run through `tart` so the external-drive/TART_HOME policy is inherited.
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -euo pipefail

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
        tart list --source local 2>/dev/null
        log "==> Configuration (per VM):"
        tart list --source local --quiet 2>/dev/null | while read -r v; do
            [[ -n "$v" ]] || continue
            log "  $v:"
            tart get "$v" 2>/dev/null | /usr/bin/sed 's/^/    /'
        done
        exit 0
        ;;
    prune)
        DAYS="${2:-30}"
        [[ "$DAYS" =~ ^[0-9]+$ ]] || die "invalid day count: $DAYS"
        tart prune --entries caches --older-than "$DAYS"
        ok "pruned cache entries older than $DAYS days"
        ;;
    prune-vms)
        DAYS="${2:?usage: tart-maint.sh prune-vms <days>}"
        [[ "$DAYS" =~ ^[0-9]+$ ]] || die "invalid day count: $DAYS"
        tart prune --entries vms --older-than "$DAYS"
        ok "pruned local VMs older than $DAYS days"
        ;;
    *)
        die "unknown cmd: $CMD (list|prune|prune-vms)"
        ;;
esac
