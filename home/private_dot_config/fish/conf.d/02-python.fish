# ── Mamba / Micromamba ────────────────────────────────────────
# Gate on the binary existing so non-Homebrew machines skip cleanly
# (mirrors .zshenv's {{ if lookPath "micromamba" }}). $HOMEBREW_PREFIX is
# set in 00-env.fish for ALL shells, so this works in non-login shells too —
# unlike a PATH-based `type -q` check.
if test -n "$HOMEBREW_PREFIX"; and test -x "$HOMEBREW_PREFIX/opt/micromamba/bin/mamba"
    set -gx MAMBA_EXE "$HOMEBREW_PREFIX/opt/micromamba/bin/mamba"
    set -gx MAMBA_ROOT_PREFIX ~/mamba

    # Shell hook + activate costs ~30ms of forks; only run for login shells.
    # auto_activate_base:true in ~/.condarc handles base activation.
    if status is-login
        $MAMBA_EXE shell hook --shell fish --root-prefix $MAMBA_ROOT_PREFIX | source
        set -gx MAMBA_NO_PROMPT 1
        # Re-prepend mamba/bin so mamba's python wins over brew's python@3.x
        fish_add_path --move --prepend $MAMBA_ROOT_PREFIX/bin
    end
end

# ── Pixi (project Python environments) ──────────────────────
if type -q pixi
    set -gx PIXI_HOME ~/.pixi
    fish_add_path --move $PIXI_HOME/bin
end
