# Windows 11 Parallels VM: session troubleshooting & rebase playbook

Notes from the 2026-08 Win11 ARM64 VM cleanup session on macOS. Complements
`win11-stubborn-removal.md` (how to remove stubborn Appx/Defender). This file
covers the rest of what was actually verified working, plus the snapshot/rebase
lesson that cost ~25 GB of external disk.

## Prism

The VM `Windows 11 (1) (1) (1)` (UUID `{0d72772b-b576-4202-b14e-aefd9790f522}`)
lives at `~/Parallels/Windows 11.pvm` on an ARM Mac (Parallels Desktop 26.2.2,
`prlctl 26.2.2`). Guest user `jacob` / `REDACTED_AUTOLOGON_PASSWORD`. Tools: `git`, `uv`,
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

# 3. (optional, if --online-compact wasn't already on) set it explicitly
prlctl set "$VM" --device-set hdd --online-compact on

# 4. re-create the two checkpoints you want to keep (post-clean, post-data)
prlctl snapshot "$VM" --name "snapshot3-final" -d "flat base, fully clean"
prlctl snapshot "$VM" --name "snapshot4-userdata" -d "user data restored"
```

**Result:** 65 GB → **52.6 GB** single flat `.hds` layer with two 2 MB
checkpoint deltas. A target of ~40 GB was **not achievable** — the guest
filesystem genuinely holds ~52 GB (Win11 24H2 + Weisoft + dev tools + user
data). Be skeptical of "should be ~40 GB" expectations; the correct expectation
after a clean debloat on this stack is ~50–55 GB.

### Why `du`/`df` look weird afterwards

The disk is `expanded` (thin-provisioned, up to 300 GB) with
`online-compact=on`. After flatten+TRIM, most freed blocks are **sparse holes**:
`du` on the host shows ~52 GB while the guest still reports ~298 GB "used" of
299 GB. **That is expected and healthy** — the file is 52 GB; it only grows if
the guest actually writes new data.

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
