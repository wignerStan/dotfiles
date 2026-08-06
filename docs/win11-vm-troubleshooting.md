# Windows 11 Parallels VM: session troubleshooting & rebase playbook

Notes from the 2026-08 Win11 ARM64 VM cleanup session on macOS. Complements
`win11-stubborn-removal.md` (how to remove stubborn Appx/Defender). This file
covers the rest of what was actually verified working, plus the snapshot/rebase
lesson that cost ~25 GB of external disk.

## Prism

The VM `Windows 11 (1) (1) (1)` (UUID `{0d72772b-b576-4202-b14e-aefd9790f522}`)
lives at `~/Parallels/Windows 11.pvm` on an ARM Mac (Parallels Desktop 26.2.2,
`prlctl 26.2.2`). Guest user `jacob` / `P@ssw0rd!VM`. Tools: `git`, `uv`,
Python (aarch64), `7z`, `GeekUninstaller` are under `~/.local` / `~/.local/share/uv` /
`%LOCALAPPDATA%` and on the Machine PATH.

### prlctl gotchas learned

- **`prlctl compact` does not exist** (prints usage listing
  snapshot/snapshot-delete/snapshot-list/snapshot-switch). Disk compaction is done
  via the guest + `--device-set hdd --online-compact on` (see Rebase below).
- Snapshot delete is order-sensitive: delete **leaf → root** (oldest last).
- Copying files into the guest: `prlctl exec <vm> --user U --password P copy
  \\Mac\Home\file C:\path\file` **fails intermittently** — the reliable path is
  `cmd /c 'copy \\mac\home\file C:\path\file'` (shared folder is
  `\\Mac\Home` on Z:, `\\Mac\External` on Y:).
- `prlctl exec` non-interactive output is UTF-8 on the host; a guest whose
  codepage is GBK (Chinese apps like WinStock) needs
  `... | iconv -f GBK -t UTF-8`. Interactive `prlctl enter` via piped stdin +
  `exit\n`.

## Verified working fixes (this session)

### 1. Winsas / Win11Debloat cleanup went all the way

- Edge **fully** removed: no `MicrosoftEdge.Stable` appx, no `msedge.exe`, no
  EdgeUpdate. `C:\Program Files (x86)\EdgeCore` stays — that is the required
  **WebView2** runtime (`msedgewebview2.exe` present, e.g.
  `150.0.4078.105`), do **not** delete it. SecHealthUI gone from WindowsApps.
- Defender realtime **off** (`DisableRealtimeMonitoring=$true`) and Tamper
  Protection disabled (GUI toggle after temporarily re-adding SecHealthUI, then
  re-removing) — see `win11-stubborn-removal.md`.
- Appx total ≈ 58. Start Menu free of Edge/Security links.
- Also: `C:\Windows.old` was found **empty** (0 GB data) after debloat —
  do not bother cleaning it for space.

### 2. Data restore paths (where things actually live)

Earlier assumptions about `C:\Weisoft` and `C:\Users\jacob\AppData\Roaming\chezmoi`
were **wrong** after debloat/restore. Verified real locations:

| Data | Real path | Notes |
|------|-----------|-------|
| Stock client | `C:\Weisoft Stock(x64)\WinStock.exe` (+ `Data`, `FinanceData.xml`) | note the space |
| chezmoi config | `C:\Users\jacob\.config\chezmoi\` | `chezmoi.toml`, `age-key.txt`, `chezmoistate.boltdb` |
| chezmoi backups | `...\chezmoi.toml.vm-backup`, `chezmoistate.boltdb.vm-backup` | pre-restore refs kept as `.vm-backup` |
| SSH | `C:\Users\jacob\.ssh\` | `config`, `config.vm-backup`, `id_chezmoi.pub`, `known_hosts` |

### 3. 徽商期货快期V3 (Kuaiji) — NOT recoverable

`C:\徽商期货快期V3` does not exist in the guest and the source disk `X:`
(where it lived on the old machine) is **gone**. `robocopy X:\徽商期货快期V3`
fails — the source never existed on this VM. This is a **known permanent gap**;
reinstall from vendor instead. Do not retry the copy scripts.

### 4. WinStock GUI automation — debug history & lessons

The Weisoft stock client (`C:\Weisoft Stock(x64)\WinStock.exe`, **note the space**
in `Stock(x64)`) has a GBK/Chinese-encoded first-launch dialog that must be
dismissed before it is usable. Getting it to start and stay started was a
multi-hour debug session; the probe scripts are kept under
`scripts/winvm/winstock/` and the actual working sequence below is what was
verified.

**The problem:** on first launch from a fresh VM WinStock shows a modeless error
dialog ("无法创建服务进程"-type flow; codepage GBK). A plain `start` / `Popen`
leaves it stuck on that dialog; `connect()` from pywinauto either fails or the
window never appears unless the dialog is acknowledged.

**Debug history (what each probe was for):**

| script | what it tried / found |
|--------|----------------------|
| `winstock-test.bat` | earliest probe: `start "" /D "C:\Weisoft Stock(x64)" WinStock.exe`, wait 25 s, check `tasklist`, dump window+controls via pywinauto |
| `winstock-auto.py` | poll every 5 s (up to 60 s) with `Application(backend='uia').connect(path=...)`, dump each window's title + class |
| `winstock-gui.py` | same, but specifically detects the error dialog by scanning window titles |
| `winstock-watch.py` | baseline `tasklist` snapshot, watch for the new WinStock process appearing |
| `winstock-detail.py` | deep dump: every descendant control (`Text/Edit/Button/Hyperlink`), auto-click `确定` to dismiss the dialog, then re-dump |
| `winstock-test2.py` | after 25 s, look for the error dialog, click `确定`, wait, re-enumerate |
| `winstock-final.py` | the keeper — 14×5 s poll, auto-dismiss, dump buttons/edits of the first 2 windows, break on success |
| `reg-task.ps1` | registers a scheduled task (interactive, `Highest`) that runs `winstock-watch.bat` | 

**Lessons that cost the most time (all verified as true):**

1. **Launch `cwd` is required**: run from the install dir
   (`/D "C:\Weisoft Stock(x64)"`), or the app can't find its
   `Data/FinanceData.xml` etc. `Popen([...], cwd=r'C:\Weisoft Stock(x64)')`.
2. **Backend must be `uia`** and you connect **by path**
   (`Application(backend='uia').connect(path=r'C:\Weisoft Stock(x64)\WinStock.exe')`)
   — default `win32` backend can't see the modern (WinUI/WebView?) tree.
3. **Window text is often empty / GBK**: `window_text()` may return `''` for
   some windows; always check `class_name()` too, and pass titles through
   `iconv -f GBK -t UTF-8` on the host side.
4. **It takes up to ~60-70 s** after spawn before a window appears — the 5 s
   poll loop is intentional; do **not** `connect` once and give up.
5. **The auto-dismiss flow** (find the error dialog → click `确定` → re-connect)
   is the whole point: once acknowledged the client stays up in later
   launches and subsequent boots don't need the scripts at all.
6. **pywinauto needs its post-install step** in a uv-managed python:
   `pywin32_postinstall.py -install` (see `env/fix-pywinauto.ps1`), otherwise
   `import pywinauto` fails on a fresh `uv run` env. chezmoi now gates pywinauto
   by `tier`/`profile` (commit `d57f415`: tier simple|develop **or** profile
   work → install; standard + non-work → skip).
7. **Interactive session**: the client needs a logged-in interactive desktop to
   show windows — a `prlctl exec`/scheduled non-interactive context can start the
   process but the window won't be visible/automateable. Use an interactive
   scheduled task (`reg-task.ps1` uses `Interactive` + `Highest`).

**End state:** `winstock-final.py` is the working auto-start+dismiss probe; the
pure `auto/gui` probes were superseded and are kept only as reference.

## Rebase & compaction playbook (the big lesson)

### What happened

The VM had 4 snapshots (S1..S4, ~65 GB total) on top of a 300 GB `expanded`
disk. After a **clean** debloat + user-data restore we wanted to keep only two
checkpoints and shrink the disk. Deleting snapshot layers did **not** free the
space: the base `.hds` layer (52.5 GB) had pinned pre-debloat blocks, and the
on-disk file only shrank when the guest TRIMmed and the host compacted.

### The working sequence (do this AFTER all guest work is done)

```bash
# 0. from macOS: shut the VM down
prlctl stop "$VM"

# 1. flatten — delete snapshots leaf → root (oldest last)
prlctl snapshot-delete "$VM" --id "$NEWEST_SNAP_UUID"
prlctl snapshot-delete "$VM" --id "$MIDDLE_SNAP_UUID"
prlctl snapshot-delete "$VM" --id "$OLDEST_SNAP_UUID"
prlctl snapshot-list "$VM"          # expect: empty

# 2. guest TRIM — boot, run Optimize-Volume -ReTrim, shut down
prlctl start "$VM"
#   (inside guest, as admin:) Optimize-Volume -DriveLetter C -ReTrim
prlctl stop "$VM"

# 3. force a real host-side compact (prlctl has no compact op)
prl_disk_tool compact --info --hdd "$HDD"   # "Used blocks" = true data (MB)

# 4. re-create the two checkpoints you want to keep (post-clean, post-data)
prlctl snapshot "$VM" --name "snapshot3-final" -d "flat base, fully clean"
prlctl snapshot "$VM" --name "snapshot4-userdata" -d "user data restored"
```

**Result:** 72 GB (52.6 base + 19.5 live) → **24 GB** total (21 GB flat base +
3 GB deltas). The two big wins:
- guest-side `Optimize-Volume C -ReTrim` only staged the free blocks;
- **`prl_disk_tool compact` on a stopped VM** is the real shrinker. It scans
  NTFS, drops stale allocated-but-unused blocks, and rewrote the layer
  `60 G → 21 G` (info showed 61549 allocated / 21098 used blocks before).

> **Skeptic's note (the 52.6 GB "only a system?" hunch):** it was partly right.
> guest `Get-PSDrive C` reports ~282–298 GB "used" **even though real guest
> files are ~23 GB**. The excess was NOT real data — it was (a) sparse holes the
> host tracks and (b) ~37 GB of  stale freed blocks still `Allocated` in the
> layer. Only the host-side `compact` (not guest TRIM, not snapshot-delete)
> reclaims those. Expect ~21 GB on a clean Win11 24H2 + Weisoft + dev tools.

### Why `du`/`df` look weird afterwards

The disk is `expanded` (thin-provisioned, up to 300 GB) with
`online-compact=on`. After flatten+TRIM, most freed blocks are **sparse holes**:
`du` on the host shows the true size while the guest reports ~282 GB "used" of
299 GB — the guest number is **untrustworthy** (it counts sparse phantom
blocks). Trust `prl_disk_tool compact --info`'s `Used blocks` instead.

### Moving the VM to its final home

- Verified `ditto` copy of the whole `.pvm`, then `shasum -a 1` the big `.hds`
  layer to confirm byte-identical before unregistering the external copy.
- `prlctl unregister "$VM"` → `prlctl register "/Users/jacob/Parallels/Windows 11.pvm" --preserve-uuid`
  keeps the UUID stable (`prlctl list -i` shows `Home` path updated).
- Boot-verify in the new home, then (only after user manual verification)
  delete the external working copy + ORIGINAL-backup + Windows install images.

## Cleanup status / open items

- [ ] External backup deletion — **hold until user manually verifies** the moved VM.
- [ ] 徽商期货快期V3 — unrecoverable (source X: gone); reinstall from vendor.

## Script layout (this repo)

The one-off session scripts that were scattered across `~/` are curated into
`home/scripts/winvm/<category>/` (applies to `~/scripts/winvm/` here and to
`C:\Users\jacob\scripts\winvm\` in the guest via chezmoi):

| Category | Holds |
|----------|-------|
| `debloat/` | Win11Debloat run (vm-debloat3), aggressive/stubborn removal, appx/winget/OneDrive removal, the SYSTEM takeown+reg-delete DesktopAppInstaller trio (`vm-rm-dai*.ps1`, `vm-takeown-dai.ps1`), dism/tile/final-clean |
| `defender/` | kill/own/tamper-off/bootfix/disable-backend + `vm-defstate.ps1` (state check), `vm-restore-setup.ps1` (permanent disable) |
| `security/` | SecHealthUI re-add/rereg, KB5007651, WebView2/Edge restore for the Security GUI, `vm-find-sechealth.ps1`, dependency probe |
| `restore/` | user-data restore + Weisoft robocopy + backup scripts |
| `runtime/` | VC90/VC2008/VC-redist, regsvr32/x86 registration, WebView2 fix, hive import |
| `env/` | PATH/UAC/autologon set, pywinauto fix, bootstrap, chezmoi pull/reapply |
| `verify/` | `final-check.ps1` + debloat/user-data WebView2 verification probes |
| `maintenance/` | `vm-trim.ps1` (Optimize-Volume -ReTrim) |
| `winstock/` | WinStock GUI automation debug history (§4): `final` (working auto-start+dismiss), `auto/gui/detail/watch/test` probes, `reg-task.ps1` (interactive scheduled task) |

Everything else from the session (per-step logs, reg dumps, `dp*/deep*/diag*/inspect*/find*/wtest*/wh6*` probes,
superseded iterations like `vm-debloat{1,2}`, `verify{2,3,4}`, `vm-fixmamba{1,2}`…) was **deleted** — the
lessons are kept here and in `win11-stubborn-removal.md`, the working scripts above are committed.
