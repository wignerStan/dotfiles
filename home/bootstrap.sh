#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Jacob's Bootstrap — Stage 1: install Homebrew + age + chezmoi, pull dotfiles
# Run on a fresh machine: curl -fsSL <repo>/bootstrap.sh | bash
# This is NOT a chezmoi template — it runs BEFORE chezmoi exists, so there is
# no cross-machine detection here; it deliberately stays plain POSIX-ish bash.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── Environment overrides (defaults for Jacob) ─────────────────
# Everything below is overridable per-env without editing this file:
#   GITHUB_USER    github login  (drives the dotfiles repo URL + git email)
#   DOTFILES_REPO  full SSH clone URL (used as fallback)
#   DOTFILES_HTTPS  clone URL (tried first; fresh machines may lack SSH keys)
#   NAME / EMAIL   git identity seed (only if nothing set locally yet)
CUR_USER="${USER:-$(id -un)}"
GITHUB_USER="${GITHUB_USER:-wignerStan}"
NAME="${NAME:-Jacob}"
EMAIL="${EMAIL:-240170694+${GITHUB_USER}@users.noreply.github.com}"
DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:${GITHUB_USER}/dotfiles.git}"
DOTFILES_HTTPS="${DOTFILES_HTTPS:-https://github.com/${GITHUB_USER}/dotfiles.git}"

echo "=== Bootstrap Stage 1: user=${CUR_USER} github=${GITHUB_USER} ==="

# 1. Install Homebrew (if not present)
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# 2. Install chezmoi + age (git comes as a brew dependency; age is needed to
#    decrypt .chezmoidata/secrets.toml.age on the FIRST apply, before any
#    template-rendered config exists). gpg comes as a brew dependency of age.
echo "Installing chezmoi + age..."
brew install chezmoi age 2>/dev/null || {
    brew install chezmoi 2>/dev/null || true
    command -v age &>/dev/null || brew install age 2>/dev/null || true
}

# 3. Init the source repo (no apply yet — decrypt secrets first)
echo "Cloning dotfiles source..."
chezmoi init "$DOTFILES_HTTPS" || chezmoi init "$DOTFILES_REPO"

# 4. Decrypt per-device secrets from the age-encrypted source BEFORE applying,
#    so the data is populated when templates render.
SRC_DIR="$(chezmoi source-path)"
DATA_DIR="$SRC_DIR/.chezmoidata"
AGE_KEY="${AGE_KEY:-$HOME/.config/chezmoi/age-key.txt}"
SOURCE_ROOT="$(git -C "$SRC_DIR" rev-parse --show-toplevel)"
SRC_SECRETS="$SOURCE_ROOT/secrets.toml.age"
if [ -f "$SRC_SECRETS" ]; then
    if [ ! -f "$AGE_KEY" ]; then
        echo "age can decrypt .chezmoidata secrets but no key at $AGE_KEY."
        echo "Provide one via 'AGE_KEY=/path/to/age-key.txt' or place it there."
        echo "Continuing WITHOUT secrets so non-secret files can still apply."
    else
        mkdir -p "$DATA_DIR"
        SECRETS_TMP="$(mktemp "$DATA_DIR/.secrets.toml.XXXXXX")"
        chmod 600 "$SECRETS_TMP"
        if age -d -i "$AGE_KEY" "$SRC_SECRETS" > "$SECRETS_TMP"; then
            mv "$SECRETS_TMP" "$DATA_DIR/secrets.toml"
            chmod 600 "$DATA_DIR/secrets.toml"
            echo "Decrypted secrets.toml.age -> .chezmoidata/secrets.toml"
        else
            rm -f "$SECRETS_TMP"
            echo "Warning: age decrypt failed for $SRC_SECRETS (secrets left unset)."
        fi
    fi
fi

# 5. Apply dotfiles (triggers Stage 2: run_once_setup.sh)
echo "Applying dotfiles..."
chezmoi apply

# 6. Seed a git identity from env if none is set anywhere yet.
if ! git config --global user.name &>/dev/null; then
    git config --global user.name  "${NAME:-Jacob}"
    git config --global user.email "${EMAIL:-$CUR_USER@localhost}"
    git config --global init.defaultBranch main
    git config --global pull.rebase true
    echo "Git identity configured (env defaults)."
fi

echo "=== Bootstrap complete! Stage 2 (package setup) ran via chezmoi. ==="
