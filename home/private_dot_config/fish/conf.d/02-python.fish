# ── Mamba / Micromamba ────────────────────────────────────────
# Uses $HOMEBREW_PREFIX (set in 00-env.fish) for cross-platform path.
set -gx MAMBA_EXE "$HOMEBREW_PREFIX/opt/micromamba/bin/mamba"
set -gx MAMBA_ROOT_PREFIX ~/mamba

# Shell hook + activate costs ~30ms of forks; only run for login shells.
# auto_activate_base:true in ~/.condarc handles base activation.
if status is-login
    eval $MAMBA_EXE shell hook --shell fish --root-prefix $MAMBA_ROOT_PREFIX | source
    set -gx MAMBA_NO_PROMPT 1
    # Re-prepend mamba/bin so mamba's python wins over brew's python@3.x
    fish_add_path --move --prepend $MAMBA_ROOT_PREFIX/bin
end

# ── Pixi (project Python environments) ──────────────────────
set -gx PIXI_HOME ~/.pixi
fish_add_path --move $PIXI_HOME/bin
