# AGENT.md — working agreement for AI agents in this chezmoi dotfiles repo

Short guide for safe, convention-preserving edits. Read before changing anything.

## Repo layout

- Source root: `~/.local/share/chezmoi` (this git repo). `.chezmoiroot` = `home`,
  so **everything that gets applied lives under `home/`**; files at the repo root
  (`.chezmoiroot`, `secrets.toml.age`, `docs/`) are meta, not applied.
- Home target = a real user's `$HOME`. `dot_` → `.` (e.g. `dot_zshenv.tmpl` →
  `~/.zshenv`), `private_` → executable/private, `.tmpl` suffix = Go template.
- Only files with template syntax need the `.tmpl` suffix. Static files tracked
  in `home/` under `scripts/` (winvm, tartvm) ship as-is.

## Variant model (three orthogonal axes — do not conflate)

Computed in `home/.chezmoi.toml.tmpl` (data exposed to every template):

- **profile** — exact one: `personal` | `work` | `vps` | `hpc`. Auto-detected
  (codespaces/root→vps, apptainer→hpc). Identity primary.
- **tier** — `default` | `system` | `develop` | `calculate` | `simple`.
  `develop` = dev user; `simple` = VM/container (minimal); `calculate` = cal
  user (linux); `system` = explicit only. default = fallback. Auto-detect via
  username + DMI "Virtual/Parallels" or `CHEZMOI_TIER` override.
- **setup_mode** — `full` | `basic` (orthogonal breadth control: full = CLI +
  GUI/media/dev tools; basic = minimal).

Package/tool breadth is level-gated in `home/run_once_setup.sh.tmpl`:
Level 1 basic (all non-simple tiers), Level 2 extra (`setup_mode=full`),
Level 3 develop (`tier=develop`).

## Non-negotiables

- **Secrets**: never put plaintext secrets in git. Encrypted secrets live in
  `secrets.toml.age` (age-encrypted, recipient pinned in `.chezmoi.toml.tmpl`).
  The plaintext decrypts to `home/.chezmoidata/secrets.toml` which is gitignored.
  Regenerate the `.age` file with `age -e -r <recipient> -o secrets.toml.age <plaintext>`.
- **`*.asc`, `*_local`** — gitignored / never synced (see `.gitignore`).
- **No hardcoded usernames/paths.** VM scripts (winvm/tartvm) resolve the runtime
  user (`Winlogon\DefaultUserName`, `$env:USERPROFILE`, `HOME`) instead of
  `C:\Users\jacob` / a pinned macOS user. Keep it that way.
- **Windows batch files must be pure ASCII (or GBK for Chinese status strings)** —
  guest codepage is GBK(936); stray UTF-8 breaks cmd parsing. Re-encode (not
  just save) when adding non-ASCII.
- **Shell is zsh-primary, fish-mirror.** A startup/env change should land in BOTH
  `dot_zshenv.tmpl`/`dot_zshrc.tmpl` AND the `fish/conf.d/`.
- **`run_onchange_*` and `run_once_*` scripts must render EMPTY on platforms where
  they must not run**, or chezmoi will execute them. Always gate by
  `{{ if eq .chezmoi.os "..." }}` and/or tier, then verify with the render checks below.

## VM deploys

- `home/scripts/winvm/` — Windows VM (Parallels) suite: debloat/defender/security/
  restore/runtime/env/verify/winstock/maintenance. Guest entry: `bootstrap-win.ps1`.
- `home/scripts/tartvm/` — macOS VM (tart) suite: create/verify/env/maintenance.
  tart is **mac-only**; install is gated to `tier=develop`
  (`run_onchange_macos-tart-setup.sh.tmpl`). A default/basic-tier Mac must NOT get
  tart auto-installed — and `TART_HOME` resolves at runtime (external vs ~/.tart).

## How to verify safely

Always dry-run before applying: `chezmoi apply --dry-run --no-tty` (or `chezmoi diff`).
Real apply needs `--force --no-tty` to bypass the interactive bootstrap prompt.

- Template render for one host: `chezmoi execute-template < file.tmpl`
  (stdin render uses live config data). Cross-OS/tier checks use
  `chezmoi execute-template --override-data='{"chezmoi":{"os":"linux"},"tier":"..."}'`
  — the flag is `--override-data` (NOT `--data`).
- `bash -n` then `shellcheck` any edited sh script.
- Check `git diff --stat` scope before committing; never stage `~`-clobbering junk.

Silent footguns: `chezmoi apply` re-runs `run_once_/run_onchange_` scripts, which
can be slow (brew/mamba). A long apply is expected, not a hang — but always gate new
scripts so they don't fire on tiers/machines that must skip them.