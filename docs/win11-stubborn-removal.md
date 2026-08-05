# Removing stubborn Win11 system components (when Win11Debloat can't)

Win11Debloat (`run_onchange_windows-bootstrap.ps1.tmpl`) handles the common
bloatware (Xbox, Clipchamp, Bing, telemetry tweaks, etc.). But some Win11 24H2
system components **resist `Remove-AppxPackage`** with error `0x80070032`
("this app is part of Windows"). This documents the methods that actually work,
learned the hard way on a Parallels Win11 ARM64 VM.

## The two layers of a system Appx

Every system Appx package has:
1. **Runtime copy** — `C:\Program Files\WindowsApps\<pkg>\`
2. **Registration** — registry under
   `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\`
   (subkeys: `Staged`, `Config`, `S-1-5-21-…\<user>`, `Deprovisioned`)

`Remove-AppxPackage` removes (1) but the deployment API (`AppXSvc`) **refuses
to de-stage** base-image packages (the `0x80070032` error). It also re-creates
the runtime copy from the master at the next boot, making removal look
non-sticky. The trick: remove (1) via takeown, and (2) via direct registry
delete, bypassing the deployment API entirely.

## Method: the working sequence

All steps run as **`NT AUTHORITY\SYSTEM`** (via a scheduled task with
`New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount`).
SYSTEM can delete `AppxAllUserStore` keys directly — no ownership dance needed
for these keys (unlike the Defender ELAM keys, below).

### 1. Remove the runtime files (takeown + icacls + delete)

```powershell
$loc = "C:\Program Files\WindowsApps\<PackageFullName>"
& takeown.exe /f $loc /r /d Y
& icacls.exe $loc /grant "*S-1-5-18:(OI)(CI)F" "Administrators:(OI)(CI)F" /t /c /q
Remove-Item -LiteralPath $loc -Recurse -Force
```

Run as SYSTEM (scheduled task) — SYSTEM has TrustedInstaller-level file access
where even an admin user's takeown fails.

### 2. Remove the registry registration (bypass the deployment API)

`Remove-AppxPackage` fails; `reg.exe delete` as SYSTEM succeeds:

```powershell
$store = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"
# find all keys for the package (per-user staging + Deprovisioned + Staged)
reg query $store /s /f "<PackageName>" /k          # enumerate
reg delete "$store\S-1-5-21-…\<user>\<PackageFullName>" /f
reg delete "$store\Deprovisioned\<PackageFamilyName>" /f
```

This is the key insight: **the deployment API is what blocks removal, not the
registry permissions.** Deleting the registry directly works.

### 3. Flush the StateRepository cache

`Get-AppxPackage` reads from the `StateRepository` DB, which caches the package
list. After deleting the registry, it still shows "present" until reconciled:

```powershell
Restart-Service AppXSvc      # flush deployment cache
# or reboot — the StateRepository reconciles with the registry on boot
```

## Confirmed working targets (Win11 24H2)

| Package | Files (takeown) | Registry (reg delete) | Notes |
|---------|:---:|:---:|---|
| `Microsoft.WindowsStore` | n/a (Appx API worked) | auto | `Remove-AppxPackage -AllUsers` worked directly |
| `Microsoft.StorePurchaseApp` | n/a | auto | worked directly |
| `Microsoft.DesktopAppInstaller` (winget) | ✅ SYSTEM takeown | ✅ reg delete | `Remove-AppxPackage` gave `0x80070032`; the registry delete + reboot made `Get-AppxPackage` report gone |

## What CANNOT be removed by any running-system method: Defender (ELAM-protected)

`WinDefend` service + Tamper Protection keys are protected by **ELAM**
(Early Launch Anti-Malware) ACLs — even **SYSTEM with `SeTakeOwnershipPrivilege`**
enabled gets "unauthorized operation" trying to take ownership of:

- `HKLM:\SOFTWARE\Microsoft\Windows Defender\Features` (TamperProtection)
- `HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend` (Start=4)

### The working Defender workaround

1. **Temporarily restore the Security UI** so you can toggle Tamper Protection
   in the GUI (required — there is no software-only way to disable Tamper
   Protection on a live 24H2 system):
   ```powershell
   # SecHealthUI is staged in the component store — re-add it
   dism /Online /Get-ProvisionedAppxPackages | findstr SecHealth
   Add-AppxPackage -Register "C:\Windows\SystemApps\Microsoft.SecHealthUI*\AppxManifest.xml"
   Add-AppxPackage -Register "C:\Windows\SystemApps\Microsoft.MicrosoftEdge*\AppxManifest.xml"  # WebView
   ```
   Then in the GUI: **Windows Security → Virus & threat protection → Tamper Protection → Off.**
2. After Tamper Protection is OFF, the Defender registry keys become writable:
   ```powershell
   Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" TamperProtection 0
   Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" Start 4
   Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc" Start 4
   ```
   These now survive reboot.
3. **Without the GUI toggle**, the fallback that does stick: a **boot-triggered
   scheduled task** re-applying `Set-MpPreference -DisableRealtimeMonitoring $true`
   at every `AtStartup` — the service runs but does no scanning.

### If the Security GUI can't open (WebView broken)

If Edge/SecHealthUI were removed (as in aggressive debloat), the Security app
can't render ("Virus & threat protection cannot open"). Re-add both from the
SystemApps manifests (above), use the GUI to toggle Tamper Protection, then
re-remove them if desired.

## Summary: which lever to pull

| Goal | Method |
|------|--------|
| Ordinary bloatware | Win11Debloat / `Remove-AppxPackage` |
| System Appx (winget, Store) that gives `0x80070032` | takeown files as SYSTEM + `reg.exe delete` registry + reboot |
| Defender service fully off | Toggle Tamper Protection in GUI (after restoring SecHealthUI) → set service `Start=4`; else boot-task re-applies `Set-MpPreference` |
| Defender ELAM registry keys without GUI | **Not possible** on a live 24H2 system — offline image servicing only |
