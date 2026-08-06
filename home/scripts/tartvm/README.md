# tart macOS-VM host: layout, deploy + hardening

tart (`openai/tools/tart`) runs macOS VMs on Apple Silicon via the
Virtualization.framework. This is the macOS-only counterpart to the
`scripts/winvm/` Windows-VM suite, with the same hardening principles:
age/encryption, env-driven paths (no hardcoded usernames), offline staging,
idempotent idempotency, and fail-loud space guards.

## Layout

```
scripts/tartvm/
  create/    tart-create.sh          pull base image (once) + create a guest VM
  env/       tart-bootstrap.sh       host-side: ensure VM, boot, copy+run guest script
             tart-guest-bootstrap.sh guest-side: install chezmoi, place age key, apply
  verify/    tart-verify.sh          health check (tart, TART_HOME, guest state)
  maintenance/tart-maint.sh          list | budget snapshots | snapshot | prune base images
```

Recurring code lives in `run_onchange_macos-tart-setup.sh.tmpl` (darwin-gated),
which installs tart+lima, creates `TART_HOME`, and pulls a base image on first run.

## TART_HOME policy

Resolved in the managed dotfiles (zsh: `dot_zshenv.tmpl`, fish: `00-env.fish.tmpl`),
darwin-only, no per-shell fork:

- `/Volumes/External/tart` when the external drive is mounted (preferred; VMs are
  tens of GB and the internal data volume was near-full).
- else `~/.tart` fallback (space floor enforced at deploy time, not shell load).

The 60 GB internal floor and external-vs-internal refusal live in the setup +
create scripts (`tart-create.sh`, `run_onchange_macos-tart-setup.sh.tmpl`) so VM
ops never silently land on a near-full internal volume. Policy: **fail loud**, no
partial state.

## Deploy flow

1. `chezmoi apply` on the Mac runs `run_onchange_macos-tart-setup.sh.tmpl` once:
   installs tart/lima, mkdir `TART_HOME`, pulls a base image.
2. `scripts/tartvm/create/tart-create.sh --name win` creates the guest from a base
   image (offline if already pulled).
3. `scripts/tartvm/env/tart-bootstrap.sh win` boots the guest and, via
   `tart ssh` (which authenticates itself — no pinned username), stages + runs
   `tart-guest-bootstrap.sh`. That script clones the dotfiles repo, installs
   chezmoi (+ age), decrypts `secrets.toml.age` with the guest's age identity,
   and runs `chezmoi apply`.

> Note: the base macOS images ship no Homebrew by default. `tart-guest-bootstrap.sh`
> falls back to the official chezmoi install script (`get.chezmoi.io`) when `brew`
> is absent, then puts the binary in `~/.local/bin`.

## Verification

```
home/scripts/tartvm/verify/tart-verify.sh [win]
```
Checks: tart binary + version, `TART_HOME` resolves and exists, a base image is
cached, and the guest is present (with state/IP if running). Exits non-zero on any
breakage so it can gate later steps.

## Hardening applied

- **No hardcoded usernames** — `tart ssh` authenticates as the guest user; all
  guest paths are `$HOME`-relative (same sweep we ran on `scripts/winvm/`).
- **mount/space-aware** — external drive preferred; internal floor enforced
  (currently 60 GB) with a clear error instead of silent overflow.
- **idempotent** — every script is safe to re-run (`run_onchange` / `set -u` +
  pre-existence checks).
- **darwin-only** — cannot run on Linux/Windows.