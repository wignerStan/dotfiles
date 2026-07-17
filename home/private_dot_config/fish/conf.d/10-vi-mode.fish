# ── Vi mode ───────────────────────────────────────────────────────

function fish_user_key_bindings
    fish_vi_key_bindings
    # puffer_fish binds '.' '!' '$' '*' to history-expansion in normal (default)
    # mode, which overrides vi motions ($ should be end-of-line). It runs via a
    # --on-variable hook that fires during fish_vi_key_bindings above, so this
    # rebinding runs AFTER it and restores vi semantics in normal mode.
    bind -M default --erase '.' '!' '$' '*'
    bind -M default '$' end-of-line
    # Readline-style line movement in both modes (matches bash/zsh muscle memory).
    # NB: this overrides vi's ctrl-a number-increment in normal mode; use 0/$ for motions.
    bind -M insert ctrl-a beginning-of-line
    bind -M insert ctrl-e end-of-line
    bind -M default ctrl-a beginning-of-line
    bind -M default ctrl-e end-of-line
end

# Note: Don't force insert mode on every prompt - it breaks normal mode!
# Fish already resets to insert mode appropriately.

# ESC timeout — 30ms to match zsh
set -g fish_escape_delay_ms 30

# Suppress fish's built-in mode prompt (Starship handles it)
function fish_mode_prompt; end
