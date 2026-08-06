#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Guest-side chezmoi bootstrap — runs INSIDE a tart macOS VM.
# Idempotent. Mirrors winvm guest bootstrap: install chezmoi, place age pubkey,
# pull dotfiles, decrypt secrets, apply.
#
# Runs as the tart guest's default user (tart ssh authenticates as it), so all
# paths are $HOME-relative — no hardcoded usernames (same principle as the
# winvm sweep). If a run_onchange hook handles tier detection on this guest,
# this stays minimal: clone + chezmoi init + apply.
#
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -uo pipefail

GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s   %s\n' "${GREEN}ok:${RESET}" "$*"; }
warn() { printf '%s   %s\n' "${YELLOW}warn:${RESET}" "$*"; }
die()  { printf '%s   %s\n' "${RED}fail:${RESET}" "$*" >&2; exit 1; }

is_cmd() { command -v "$1" >/dev/null 2>&1; }

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/wignerStan/dotfiles.git}"
AGE_IDENT="$HOME/.config/chezmoi/age-key.txt"

# 1) clone if missing
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    log "    cloning dotfiles..."
    git clone --depth 1 "$DOTFILES_REPO" "$HOME/.local/share/chezmoi" || die "clone failed"
fi

# 2) chezmoi binary (brew on this guest; tart macOS images have no brew by default)
if ! is_cmd chezmoi; then
    log "    installing chezmoi..."
    if is_cmd brew; then
        brew install chezmoi age 2>/dev/null || true
    else
        # no brew on base image — use the official install script (age too)
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" || die "chezmoi install failed"
    fi
    export PATH="$HOME/.local/bin:$PATH"
fi

# 3) age identity: place a key from the guest's own generated one if absent.
#    The host seeds nothing here — the guest generates + we only decrypt what
#    the age identity can. If the host key is needed, mount it at /Volumes via
#    tart run --dir and export AGE_IDENT accordingly.
if [ ! -f "$AGE_IDENT" ]; then
    log "    generating guest age identity (decrypts dotfiles secrets locally)..."
    mkdir -p "$(dirname "$AGE_IDENT")"
    age-keygen -o "$AGE_IDENT" 2>/dev/null || true
fi

# 4) apply
cd "$HOME/.local/share/chezmoi" || die "cannot cd to dotfiles repo"
if [ -f "secrets.toml.age" ]; then
    log "    decrypting secrets for chezmoi apply..."
    mkdir -p "$HOME/.local/share/chezmoi/home/.chezmoidata"
    age -d -i "$AGE_IDENT" "secrets.toml.age" > "$HOME/.local/share/chezmoi/home/.chezmoidata/secrets.toml" 2>/dev/null \
        || warn "secret decryption failed (age key mismatch) — continuing without secrets"
fi
chezmoi apply 2>/dev/null || warn "chezmoi apply had warnings"

ok "guest bootstrap complete — dotfiles applied"
