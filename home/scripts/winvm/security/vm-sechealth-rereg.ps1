$log = "C:\Users\jacob\Downloads\sechealth-rereg.txt"
"" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# 1. Is the windowsdefender:// protocol registered + pointing at SecHealthUI?
W "=== protocol handler ==="
$proto = "HKLM:\SOFTWARE\Classes\windowsdefender"
if (Test-Path $proto) {
    $sub = Get-ItemProperty "$proto\shell\open\command" -EA SilentlyContinue
    W "  command: $($sub.'(default)')"
} else { W "  windowsdefender:// NOT registered" }

# 2. SecHealthUI real manifest location (the package, not a stub)
W "`n=== SecHealthUI package manifest ==="
$pkg = Get-AppxPackage -Name "Microsoft.SecHealthUI" -EA SilentlyContinue
W "  location: $($pkg.InstallLocation)"
$manifest = Join-Path $pkg.InstallLocation "AppxManifest.xml"
W "  manifest: $(Test-Path $manifest)"

# 3. Re-register the FULL package for the current user (not SystemApps stub)
W "`n=== re-register full SecHealthUI for current user ==="
if (Test-Path $manifest) {
    try {
        Add-AppxPackage -Register $manifest -DisableDevelopmentMode -EA Stop
        W "  re-registered OK"
    } catch { W "  fail: $($_.Exception.Message)" }
}

# 4. Ensure SecurityHealthService is running + automatic
W "`n=== service ==="
Set-Service SecurityHealthService -StartupType Automatic -EA SilentlyContinue
Start-Service SecurityHealthService -EA SilentlyContinue
$svc = Get-Service SecurityHealthService -EA SilentlyContinue
W "  SecurityHealthService: $(if($svc){$svc.Status+'/'+$svc.StartType}else{'absent'})"

# 5. Check the WVS / SecurityHealthSystray launches the WinUI host — does Microsoft.UI.Xaml.CBS exist?
W "`n=== UI.Xaml.CBS (SystemApps XAML host) ==="
$cbs = Get-AppxPackage -AllUsers -Name "Microsoft.UI.Xaml.CBS" -EA SilentlyContinue
W "  CBS: $(if($cbs){$cbs.PackageFullName}else{'ABSENT'})"
$cbsDir = "C:\Windows\SystemApps\Microsoft.UI.Xaml.CBS_8wekyb3d8bbwe"
W "  CBS folder: $(Test-Path $cbsDir)"

# 6. relaunch from THIS interactive session (as jacob)
W "`n=== relaunch ==="
Start-Process "windowsdefender://" -EA SilentlyContinue
Start-Sleep 5
$proc = Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -match "SecHealth|SecurityHealth" }
W "  procs: $(if($proc){($proc|Select -ExpandProperty ProcessName) -join ','}else{'none'})"
W "DONE"
