#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Jacob's Bootstrap — Stage 1: install Homebrew + chezmoi, pull dotfiles
# Run on a fresh machine: curl -fsSL <repo>/bootstrap.sh | bash
# This is NOT a chezmoi template — it runs BEFORE chezmoi exists.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

DOTFILES_REPO="git@github.com:wignerStan/dotfiles.git"
# Fallback to HTTPS if SSH fails (fresh machine may lack keys)
DOTFILES_HTTPS="https://github.com/wignerStan/dotfiles.git"

echo "=== Bootstrap Stage 1: Homebrew + chezmoi ==="

# 1. Install Homebrew (if not present)
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add to PATH for this session
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# 2. Install chezmoi (git comes as a brew dependency)
echo "Installing chezmoi..."
brew install chezmoi 2>/dev/null || echo "chezmoi already installed"

# 3. Init + apply dotfiles (triggers Stage 2: run_once_setup.sh)
echo "Pulling dotfiles and applying..."
chezmoi init --apply "$DOTFILES_HTTPS" || chezmoi init --apply "$DOTFILES_REPO"

echo "=== Bootstrap complete! Stage 2 (package setup) ran via chezmoi. ==="
