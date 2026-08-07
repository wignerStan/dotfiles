#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Jacob's Setup — re-pull + re-apply dotfiles on an EXISTING machine.
# Companion to bootstrap.sh (Stage 1 for fresh machines). This is the
# everyday "sync my dotfiles" entry point: it refreshes the source repo,
# decrypts secrets, and applies. It does NOT install Homebrew/chezmoi.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

CUR_USER="${USER:-$(id -un)}"
GITHUB_USER="${GITHUB_USER:-wignerStan}"
DOTFILES_SSH="${DOTFILES_SSH:-git@github.com:${GITHUB_USER}/dotfiles.git}"

echo "=== Setup: user=${CUR_USER} github=${GITHUB_USER} ==="

# 1. Refresh the chezmoi source repo.
if ! command -v chezmoi &>/dev/null; then
    echo "chezmoi not installed — run bootstrap.sh first."
    exit 1
fi
SRC_DIR="$(chezmoi source-path)"
echo "Refreshing dotfiles source at $SRC_DIR ..."
git -C "$SRC_DIR" pull --rebase || { echo "Warning: source pull failed"; }

# 2. Decrypt per-device secrets (same as bootstrap) so templates render.
DATA_DIR="$SRC_DIR/.chezmoidata"
AGE_KEY="${AGE_KEY:-$HOME/.config/chezmoi/age-key.txt}"
SRC_SECRETS="$SRC_DIR/secrets.toml.age"
mkdir -p "$DATA_DIR"
if [ -f "$SRC_SECRETS" ]; then
    if [ -f "$AGE_KEY" ]; then
        age -d -i "$AGE_KEY" "$SRC_SECRETS" > "$DATA_DIR/secrets.toml" \
            && echo "Decrypted secrets.toml.age -> .chezmoidata/secrets.toml"
    else
        echo "Warning: no age key at $AGE_KEY; secrets left unset."
    fi
fi

# 3. Apply dotfiles (triggers run_once/run_onchange hooks).
echo "Applying dotfiles..."
chezmoi apply

echo "=== Setup complete. ==="