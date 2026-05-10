# Cargo
fish_add_path --move ~/.cargo/bin

# pnpm
set -gx PNPM_HOME ~/Library/pnpm
fish_add_path --move $PNPM_HOME/bin

# Antigravity
fish_add_path --move ~/.antigravity/antigravity/bin

# Bun
set -gx BUN_INSTALL ~/.bun
fish_add_path --move $BUN_INSTALL/bin

# Local user binaries (prepended to override system commands)
fish_add_path --move --prepend ~/.local/bin
