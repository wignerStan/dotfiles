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

## Variant model (six orthogonal axes — do not conflate)

Computed in `home/.chezmoi.toml.tmpl` (data exposed to every template).
At `chezmoi init`, precedence per axis is `CHEZMOI_*` env >
`home/.chezmoidata/machine.toml` (keyed by `user@hostname`, then hostname) > auto-detection. The
generated config persists across applies. Use `--override-data` for a one-off
apply and re-run `chezmoi init` after changing machine declarations.

- **ownership** — exactly one: `personal` | `work`. Who owns the machine.
  `work` remains a minimal/reference gate (shared-cluster declarations only;
  there is no fully managed work workstation yet).
- **platform** — `local` | `cloud`. Where it runs: own hardware vs a 3rd-party
  cloud platform (VPS/HPC/codespace). Auto: codespaces/container/apptainer →
  cloud. (OS kind is a SEPARATE key `.os_platform` = darwin|linux|wsl|windows.)
- **tier** — `simple` | `default` | `advanced`. Resource/install depth.
  `simple` = minimal/1C1G → primary_shell bash; `default`/`advanced` → zsh with
  bash-align setopts (in `.zshenv`). Legacy `CHEZMOI_TIER=develop` translates
  to advanced + dev facet. The old `system`/`calculate` tiers are gone.
- **facets** — stackable list: `dev` | `proxy` | `ai` | `hpc` | `research`. Available on ANY
  tier (simple included). `dev` = former develop tier (bun/pnpm, tart, go/rust,
  L4 tools); `proxy` = xray-core/sing-box; `ai` = sub2api + CLI wrappers
  (cc/cc2/oc) — AI is NOT a dev tool, it is its own facet; `hpc` = former
  calculate tier (spack/fortran/cuda), auto-added for cal/apptainer hosts.
- **is_guest** — derived role flag, separate from tier. Machine declarations
  override Linux/Windows VM-model detection. Guest-only network decisions use
  this flag; low resource depth alone never disables a security baseline.
- **bootstrap** — `basic` | `full` (renamed from setup_mode). L2 basic vs L3
  full (packages + services).
- **deploy** — `user` (default) | `system` | `system+user`. Deploy scope, enforced
  in `run_once_setup.sh.tmpl` by runtime identity:
  - root/system user → ONLY the system scope (`system`/`system+user`); the user
    scope is run by `scripts/bootstrap-l1.sh` after dropping to the default uid
    (1000 linux / 501 darwin).
  - plain user + `user` (default) → user scope only.
  - plain user + `system` → system scope via sudo elevation.
  - plain user + `system+user` → user scope followed by sudo system scope.
  - root + `system+user` → system scope only; L1 owns the privilege drop.

Package layers (`home/run_once_setup.sh.tmpl` + `home/.chezmoidata/packages.toml`):
L1 self-bootstrap → L2 basic (all non-simple tiers; shell/dir tooling only, NO
language stack) → L3 standard (bootstrap=full: uv/mamba/node + npm
global-block + tooling/services; pnpm/bun are dev-facet-gated; pixi is research-facet) → facet overlays
(`facets.*` in packages.toml; dev carries pnpm/bun, research carries pixi). npm,
pnpm, Bun, uv, pixi, and mamba package caches use `.shared_cache` when declared
(dot_npmrc.tmpl and shell configs), otherwise their user defaults. System commands are ALWAYS sudo-elevated when not
root (native/plain-user hosts need the password; root runs them directly).
Local & cloud are NOT isolated package trees;
overlays live in `home/.chezmoi/overlay/{facets,platform}/`.

Service provisioning (cloud, not HPC): `home/run_onchange_linux-cloud-services.sh.tmpl`
— fixed order tailscale → nft → sysctl → nginx → kopia → pg/redis (tier-scaled
single/multi, ai facet only) → proxy → ai; nginx Restart=always drop-in is managed here;
conflict-warning for non-managed variant overrides (slim/full in
`.chezmoidata/facet_registry.toml`).
The nft input policy is rendered from `home/.chezmoitemplates/nftables-firewall`:
output is accepted, unsolicited input is dropped, and only established/related,
loopback, Tailscale, and an explicitly selected system-TUN exception are added.
Facet package overlays must be installed by every platform-specific package
path: dev owns pnpm/bun, research owns pixi, hpc owns spack, and ai owns
PostgreSQL/Redis. Do not put these packages back into an unconditional L3 list.

macOS PF host firewall: `home/run_onchange_install-macos-pf-firewall.sh.tmpl`.
Its resource classification is `scope=system`, `ownership=personal`,
`os=darwin`, `layer=basic` (and therefore inherited by `bootstrap=full`);
PF staging is managed for every personal Darwin host at the basic layer.
System installation reconciles for `deploy=system` and `deploy=system+user`;
plain users elevate through sudo. Guest role is `.is_guest`, never inferred
from a security resource's tier gate.

## Non-negotiables

- **Secrets**: never put plaintext secrets in git. Encrypted secrets live in
  `secrets.toml.age` (age-encrypted, recipient pinned in `.chezmoi.toml.tmpl`).
  The plaintext decrypts to `home/.chezmoidata/secrets.toml` which is gitignored.
  Repository-level ignore rules also cover `.env*`, `*.env*`, and `secrets.env*`;
  only explicitly named `*.example` files are allowed through. Review staged
  diffs and run a secret scan before every history rewrite or push.
  Regenerate the `.age` file with `age -e -r <recipient> -o secrets.toml.age <plaintext>`.
- **`*.asc`, `*_local`** — gitignored / never synced (see `.gitignore`).
- **No hardcoded usernames/paths.** VM scripts (winvm/tartvm) resolve the runtime
  user (`Winlogon\DefaultUserName`, `$env:USERPROFILE`, `HOME`) instead of
  `C:\Users\jacob` / a pinned macOS user. Keep it that way.
- **Windows batch files must be pure ASCII (or GBK for Chinese status strings)** —
  guest codepage is GBK(936); stray UTF-8 breaks cmd parsing. Re-encode (not
  just save) when adding non-ASCII.
- **Shell follows `.primary_shell`**: zsh-primary with fish-mirror on
  standard tiers; **bash on tier=simple**. A startup/env change for zsh should
  land in BOTH `dot_zshenv.tmpl`/`dot_zshrc.tmpl` AND the `fish/conf.d/`;
  simple/bash hosts get `dot_bashrc.tmpl`+`dot_bash_profile.tmpl` and ignore
  the zsh/fish files (see `.chezmoiignore.tmpl`).
- **`run_onchange_*` and `run_once_*` scripts must render EMPTY on platforms where
  they must not run**, or chezmoi will execute them. Always gate by
  `{{ if eq .chezmoi.os "..." }}` and/or tier/facets, then verify with the render checks below.

## VM deploys

- `home/scripts/winvm/` — Windows VM (Parallels) suite: debloat/defender/security/
  restore/runtime/env/verify/winstock/maintenance. Guest entry: `bootstrap-win.ps1`.
- `home/scripts/tartvm/` — macOS VM (tart) suite: create/verify/env/maintenance.
  tart is **mac-only**; install is gated to the dev facet
  (`run_onchange_macos-tart-setup.sh.tmpl`). A default/basic machine without the
  dev facet must NOT get tart auto-installed — and `TART_HOME` resolves at
  runtime (external vs ~/.tart). Tart's `admins-Virtual-Machine` declaration is
  an explicit simple/basic guest with system+user deployment; its bootstrap
  transfers `~/.ssh/id_chezmoi` and the age identity over the guest-agent channel.

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
