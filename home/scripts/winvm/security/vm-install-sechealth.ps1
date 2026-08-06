$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\install-sechealth-log.txt"
"=== install SecHealthUI appx fresh $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# copy the appx from the Mac share
$src = "\\Mac\Home\Downloads\Microsoft.SecHealthUI.appx"
$dst = "$H\Downloads\Microsoft.SecHealthUI.appx"
Copy-Item $src $dst -Force -EA SilentlyContinue
W "appx present: $(Test-Path $dst) ($([math]::Round((Get-Item $dst -EA SilentlyContinue).Length/1MB))MB)"

# remove the existing SecHealthUI registration first (clean slate)
W "`n=== remove existing registration ==="
$old = Get-AppxPackage -AllUsers -Name "Microsoft.SecHealthUI" -EA SilentlyContinue
foreach ($p in $old) {
    try { $p | Remove-AppxPackage -AllUsers -EA Stop; W "removed: $($p.PackageFullName)" }
    catch { W "remove fail: $($_.Exception.Message)" }
}

# install the fresh appx
W "`n=== install fresh appx ==="
try {
    Add-AppxPackage -Path $dst -ForceApplicationShutdown -EA Stop
    W "Add-AppxPackage: OK"
} catch { W "Add-AppxPackage fail: $($_.Exception.Message)" }

# also register for all users + SYSTEM
try { Add-AppxPackage -Path $dst -RegisterByFamilyName -MainPackage "Microsoft.SecHealthUI_8wekyb3d8bbwe" -EA SilentlyContinue } catch {}

Start-Sleep 3
$pkg = Get-AppxPackage -Name "Microsoft.SecHealthUI" -EA SilentlyContinue
W "`npkg: $(if($pkg){$pkg.PackageFullName}else{'absent'})"
W "location: $($pkg.InstallLocation)"

# verify the host (SecurityHealthService) is the right process; relaunch
W "`n=== relaunch test ==="
Start-Process "C:\Windows\System32\SecurityHealthSystray.exe" -EA SilentlyContinue
Start-Sleep 5
$proc = Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -match "SecHealth|SecurityHealth" }
W "procs: $(if($proc){($proc|Select -ExpandProperty ProcessName) -join ','}else{'none'})"

W "DONE"
Copy-Item $log "\\Mac\Home\Downloads\vm-install-sechealth-log.txt" -Force