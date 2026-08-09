#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Guest-side chezmoi bootstrap — runs INSIDE a tart macOS VM.
# Idempotent. Mirrors winvm guest bootstrap: install chezmoi, use the pre-seeded age identity,
# pull dotfiles, decrypt secrets, apply.
#
# Runs as the Tart guest agent's default user, so all
# paths are $HOME-relative — no hardcoded usernames (same principle as the
# winvm sweep). If a run_onchange hook handles tier detection on this guest,
# this stays minimal: clone + chezmoi init + apply.
#
# Managed by Chezmoi — do not edit in place.
# -------------------------------------------------------------------------------
set -euo pipefail

GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { printf '%s\n' "$*"; }
ok()   { printf '%s   %s\n' "${GREEN}ok:${RESET}" "$*"; }
warn() { printf '%s   %s\n' "${YELLOW}warn:${RESET}" "$*"; }
die()  { printf '%s   %s\n' "${RED}fail:${RESET}" "$*" >&2; exit 1; }

is_cmd() { command -v "$1" >/dev/null 2>&1; }

DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:wignerStan/dotfiles.git}"
AGE_IDENT="$HOME/.config/chezmoi/age-key.txt"
DEPLOY_KEY="$HOME/.ssh/id_chezmoi"

[[ -r "$DEPLOY_KEY" ]] || die "chezmoi deploy key was not seeded by tart-bootstrap.sh"
export GIT_SSH_COMMAND="/usr/bin/ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

# 1) clone if missing
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    log "    cloning dotfiles..."
    git clone --depth 1 "$DOTFILES_REPO" "$HOME/.local/share/chezmoi" || die "clone failed"
else
    git -C "$HOME/.local/share/chezmoi" pull --ff-only || die "dotfiles update failed"
fi
git -C "$HOME/.local/share/chezmoi" config core.sshCommand \
    "/usr/bin/ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

# 2) chezmoi binary (brew on this guest; Tart macOS images have no brew by default)
if ! is_cmd chezmoi; then
    log "    installing chezmoi..."
    if is_cmd brew; then
        brew install chezmoi age 2>/dev/null || true
    else
        # No brew on a base image: chezmoi's builtin age implementation handles
        # repository decryption, so a separate age binary is unnecessary.
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" || die "chezmoi install failed"
    fi
    export PATH="$HOME/.local/bin:$PATH"
fi

# 3) The host-side wrapper must seed the matching private identity. Generating
# an unrelated guest key would make both secrets.toml.age and managed encrypted
# files undecryptable.
[[ -r "$AGE_IDENT" ]] || die "age identity was not seeded by tart-bootstrap.sh"

# 4) Initialize config, decrypt meta-data with chezmoi's builtin age, then apply.
cd "$HOME/.local/share/chezmoi" || die "cannot cd to dotfiles repo"
chezmoi init --no-tty --promptDefaults || die "chezmoi init failed"
if [ -f "secrets.toml.age" ]; then
    log "    decrypting secrets for chezmoi apply..."
    mkdir -p "$HOME/.local/share/chezmoi/home/.chezmoidata"
    __secrets_tmp="$(mktemp "$HOME/.local/share/chezmoi/home/.chezmoidata/.secrets.toml.XXXXXX")"
    if chezmoi decrypt "secrets.toml.age" > "$__secrets_tmp"; then
        chmod 600 "$__secrets_tmp"
        mv -f "$__secrets_tmp" "$HOME/.local/share/chezmoi/home/.chezmoidata/secrets.toml"
    else
        unlink "$__secrets_tmp"
        die "secret decryption failed (age key mismatch)"
    fi
fi
# The Tart guest is declared as system+user so PF is installed. Match the
# installer's ALF preconditions before applying any system-scoped resources.
if ! sudo -n true 2>/dev/null; then
    die "passwordless sudo is required for Tart system+user deployment"
fi
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off >/dev/null
chezmoi apply --no-tty || die "chezmoi apply failed"

ok "guest bootstrap complete — dotfiles applied"
