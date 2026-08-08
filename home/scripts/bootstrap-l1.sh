#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Bootstrap L1 — SELF-BOOTSTRAP (static; usable before `chezmoi init`)
#
#   L1 =  package manager (optional) + chezmoi + age/gpg + git
#
#   This layer CANNOT use chezmoi templates. It takes parameters via
#   environment variables (L1_*), and secrets come from an age-encrypted
#   env file (secrets.env.age — see secrets.env.example in this repo).
#
#   Deploy-scope rule:
#     - running as root/system  → SYSTEM packages only, then drop privileges
#       to the default user (uid ${L1_DEFAULT_UID:-1000}; 501 on mac) for the
#       user-scope pass; system packages can be skipped entirely with
#       --skip-system.
#     - running as the default user → user-scope pass only.
#
#   Flags:
#     --skip-system   root only: skip the system-scope (apt/apk/brew) install
#     --user-pass     internal: run the user-scope pass (used after dropping
#                     privileges from root; do not call manually)
#
# Usage:
#   sudo -E env L1_FACETS="proxy,ai" ./bootstrap-l1.sh [--skip-system]
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SKIP_SYSTEM=0
USER_PASS=0
for a in "$@"; do
    case "$a" in
        --skip-system) SKIP_SYSTEM=1 ;;
        --user-pass)   USER_PASS=1 ;;
    esac
done

# ── parameters (env) ───────────────────────────────────────────────────────
L1_PKG_MGR="${L1_PKG_MGR:-}"                # brew|apt|apk|none (auto-detect if empty)
L1_DEFAULT_UID="${L1_DEFAULT_UID:-}"        # target uid for the user pass (1000/501)
L1_USER="${L1_USER:-}"                      # target username (default: owner of that uid)
L1_SECRETS="${L1_SECRETS:-}"              # age-decrypted env file (default: target user's ~/.config)
L1_SECRETS_AGE="${L1_SECRETS_AGE:-}"        # path to secrets.env.age (optional)
L1_AGE_IDENTITY="${L1_AGE_IDENTITY:-}"      # default: target user's chezmoi age identity
L1_CHEZMOI_REPO="${L1_CHEZMOI_REPO:-https://github.com/wignerStan/dotfiles.git}"

say() { printf '[L1] %s\n' "$*"; }
die() { printf '[L1] FAIL: %s\n' "$*" >&2; exit 1; }

detect_pkg_mgr() {
    if [[ -n "$L1_PKG_MGR" ]]; then
        case "$L1_PKG_MGR" in
            brew|apt|apk|none) echo "$L1_PKG_MGR"; return ;;
            *) die "invalid L1_PKG_MGR=$L1_PKG_MGR (want brew|apt|apk|none)" ;;
        esac
    fi
    command -v brew >/dev/null 2>&1 && { echo brew; return; }
    [[ -x /opt/homebrew/bin/brew || -x /home/linuxbrew/.linuxbrew/bin/brew ]] \
        && { echo brew; return; }
    command -v apt-get >/dev/null 2>&1 && { echo apt; return; }
    command -v apk >/dev/null 2>&1 && { echo apk; return; }
    echo none
}

default_uid() {
    [[ -n "$L1_DEFAULT_UID" ]] && { echo "$L1_DEFAULT_UID"; return; }
    case "$(uname -s)" in
        Darwin) echo 501 ;;
        *)      echo 1000 ;;
    esac
}

target_username() {
    [[ -n "$L1_USER" ]] && { echo "$L1_USER"; return; }
    id -un "$(default_uid)" 2>/dev/null || true
}

target_home() {
    local target=$1
    local found=""

    if command -v dscl >/dev/null 2>&1; then
        found="$(dscl . -read "/Users/$target" NFSHomeDirectory 2>/dev/null \
            | awk '{print $2}')"
    elif command -v getent >/dev/null 2>&1; then
        found="$(getent passwd "$target" 2>/dev/null | cut -d: -f6)"
    elif [[ -r /etc/passwd ]]; then
        found="$(awk -F: -v u="$target" '$1 == u { print $6; exit }' /etc/passwd)"
    fi
    [[ -n "$found" ]] || die "cannot resolve home directory for $target"
    printf '%s\n' "$found"
}

# ── 0. decrypt secrets env (age) ───────────────────────────────────────────
decrypt_secrets() {
    local identity
    local output
    local output_dir
    local temporary

    [[ -n "$L1_SECRETS_AGE" && -f "$L1_SECRETS_AGE" ]] || return 0
    command -v age >/dev/null 2>&1 || die "age not installed but $L1_SECRETS_AGE exists"
    identity="${L1_AGE_IDENTITY:-$HOME/.config/chezmoi/age-key.txt}"
    [[ -r "$identity" ]] || die "age identity is not readable: $identity"
    output="${L1_SECRETS:-$HOME/.config/secrets.env}"
    output_dir="$(dirname "$output")"
    mkdir -p "$output_dir"
    umask 077
    temporary="$(mktemp "$output_dir/.secrets.env.XXXXXX")"
    if age -d -i "$identity" "$L1_SECRETS_AGE" > "$temporary"; then
        chmod 600 "$temporary"
        mv -f "$temporary" "$output"
    else
        unlink "$temporary"
        die "failed to decrypt $L1_SECRETS_AGE"
    fi
    say "decrypted $L1_SECRETS_AGE -> $output"
}

# ── 1. system-scope pass (root only; --skip-system bypasses) ───────────────
system_pass() {
    local mgr; mgr="$(detect_pkg_mgr)"
    say "system pass: pkg-mgr=$mgr"
    case "$mgr" in
        brew)
            # Homebrew refuses root installs. The dropped user pass discovers
            # an existing standard-prefix installation and owns any brew work.
            say "Homebrew is user-scoped; deferring brew packages to the user pass"
            ;;
        apt)
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y git curl ca-certificates gnupg age sudo
            ;;
        apk)
            apk add --no-cache git curl ca-certificates gnupg age sudo
            ;;
        none)
            say "no package manager found — install git/curl manually, then re-run"
            ;;
    esac
}

# ── 2. user-scope pass (run as the default/target user) ───────────────────
user_pass() {
    say "user-scope pass (user=$(id -un))"
    local secrets_file

    if ! command -v brew >/dev/null 2>&1; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    fi
    if ! command -v git >/dev/null 2>&1; then
        say "git missing in user scope — install it, then re-run"
        return 1
    fi
    if command -v brew >/dev/null 2>&1; then
        command -v chezmoi >/dev/null 2>&1 || brew install chezmoi
        command -v age    >/dev/null 2>&1 || brew install age
        command -v gpg    >/dev/null 2>&1 || brew install gnupg
    elif ! command -v chezmoi >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    fi
    decrypt_secrets
    secrets_file="${L1_SECRETS:-$HOME/.config/secrets.env}"
    if [[ -f "$secrets_file" ]]; then
        set -a
        # shellcheck disable=SC1090
        . "$secrets_file"
        set +a
        say "$secrets_file exported for L2/L3"
    else
        say "no secrets env present — continuing without L2/L3 secrets"
    fi
    if command -v chezmoi >/dev/null 2>&1; then
        say "chezmoi ready — next: chezmoi init $L1_CHEZMOI_REPO && chezmoi apply"
    fi
}

# ── main ───────────────────────────────────────────────────────────────────
if [[ "$USER_PASS" -eq 1 ]]; then
    user_pass
    say "L1 user pass complete"
    exit 0
fi

if [[ "$(id -u)" -eq 0 ]]; then
    if [[ "$SKIP_SYSTEM" -eq 1 ]]; then
        say "--skip-system: system packages skipped (root)"
    else
        system_pass
    fi
    TARGET="$(target_username)"
    if [[ -n "$TARGET" && "$TARGET" != "root" ]]; then
        TARGET_HOME="$(target_home "$TARGET")"
        say "dropping privileges to $TARGET for user-scope pass"
        if command -v sudo >/dev/null 2>&1; then
            sudo -u "$TARGET" -H env \
                L1_PKG_MGR="$L1_PKG_MGR" \
                L1_DEFAULT_UID="$(default_uid)" \
                L1_USER="$TARGET" \
                L1_SECRETS="$L1_SECRETS" \
                L1_SECRETS_AGE="$L1_SECRETS_AGE" \
                L1_AGE_IDENTITY="$L1_AGE_IDENTITY" \
                L1_CHEZMOI_REPO="$L1_CHEZMOI_REPO" \
                bash "$0" --user-pass
        elif command -v runuser >/dev/null 2>&1; then
            runuser -u "$TARGET" -- env \
                HOME="$TARGET_HOME" \
                L1_PKG_MGR="$L1_PKG_MGR" \
                L1_DEFAULT_UID="$(default_uid)" \
                L1_USER="$TARGET" \
                L1_SECRETS="$L1_SECRETS" \
                L1_SECRETS_AGE="$L1_SECRETS_AGE" \
                L1_AGE_IDENTITY="$L1_AGE_IDENTITY" \
                L1_CHEZMOI_REPO="$L1_CHEZMOI_REPO" \
                bash "$0" --user-pass
        else
            die "cannot drop privileges: install sudo or runuser"
        fi
    else
        say "no default user found (uid $(default_uid)) — user pass skipped"
    fi
else
    user_pass
fi

say "L1 complete"
