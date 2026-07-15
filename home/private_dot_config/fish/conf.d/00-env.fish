# ── Homebrew ──────────────────────────────────────────────────
if test -x /opt/homebrew/bin/brew
    set -gx HOMEBREW_PREFIX /opt/homebrew
else if test -x /home/linuxbrew/.linuxbrew/bin/brew
    set -gx HOMEBREW_PREFIX /home/linuxbrew/.linuxbrew
end

# brew shellenv forks ~28ms; only run for login shells
if status is-login; and set -q HOMEBREW_PREFIX
    eval $HOMEBREW_PREFIX/bin/brew shellenv | source
end

# ── XDG Base Directory ──────────────────────────────────────────
set -qx XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME ~/.config
set -qx XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME ~/.cache
set -qx XDG_DATA_HOME; or set -gx XDG_DATA_HOME ~/.local/share
set -qx XDG_STATE_HOME; or set -gx XDG_STATE_HOME ~/.local/state

# ── Homebrew (China mirrors) ──────────────────────────────────
set -gx HOMEBREW_BREW_GIT_REMOTE "https://mirrors.ustc.edu.cn/brew.git"
set -gx HOMEBREW_CORE_GIT_REMOTE "https://mirrors.ustc.edu.cn/homebrew-core.git"
set -gx HOMEBREW_BOTTLE_DOMAIN "https://mirrors.ustc.edu.cn/homebrew-bottles"
set -gx HOMEBREW_API_DOMAIN "https://mirrors.ustc.edu.cn/homebrew-bottles/api"

# ── Proxy ─────────────────────────────────────────────────────
set -gx NO_PROXY "127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,100.64.0.0/10,100.100.0.0/16,localhost,*.local,*.crashlytics.com"
set -gx no_proxy $NO_PROXY

# ── Editor ────────────────────────────────────────────────────
set -gx EDITOR nvim

# ── Telemetry & API ───────────────────────────────────────────
set -gx DISABLE_TELEMETRY true
set -gx DISABLE_COST_WARNINGS true
set -gx API_TIMEOUT_MS 600000

# ── HuggingFace & Models ──────────────────────────────────────
set -gx HF_ENDPOINT https://hf-mirror.com
set -gx NANOBANANA_MODEL gemini-3-pro-image-preview

# ── iTerm2 ──────────────────────────────────────────────────────
set -gx ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX YES

# ── Fish UX ────────────────────────────────────────────────────
set -g fish_greeting ""  # no startup message
