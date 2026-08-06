$log = "C:\Users\jacob\Downloads\kb-verify.txt"
"=== verify after KB5007651 $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# properly check the host folder
W "=== host folder ==="
$saf = "C:\Windows\SystemApps\Microsoft.WindowsDefenderSecurityCenter_8wekyb3d8bbwe"
W "exists: $(Test-Path $saf)"
if (Test-Path $saf) { Get-ChildItem $saf -EA SilentlyContinue | Select-Object -First 6 | ForEach-Object { W "  $($_.Name)" } }

W "`n=== WindowsDefenderSecurityCenter.exe ==="
W "C:\Program Files\Windows Defender\WindowsDefenderSecurityCenter.exe: $(Test-Path 'C:\Program Files\Windows Defender\WindowsDefenderSecurityCenter.exe')"
W "C:\Windows\System32\SecurityHealthService.exe: $(Test-Path 'C:\Windows\System32\SecurityHealthService.exe')"

W "`n=== registry: installed KB / uninstall entry ==="
$reg = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
Get-ItemProperty $reg -EA SilentlyContinue | Where-Object { $_.DisplayName -match "Security|Defender|KB5007651" } | ForEach-Object {
    W "  $($_.DisplayName) | $($_.DisplayVersion) | $($_.InstallLocation)"
}

W "`n=== windowsdefender protocol ==="
$cmd = (Get-ItemProperty "HKLM:\SOFTWARE\Classes\windowsdefender\shell\open\command" -EA SilentlyContinue).'(default)'
W "command: [$cmd]"
# the package AppxManifest registers it — force re-register protocol
$pkg = Get-AppxPackage -Name "Microsoft.SecHealthUI" -EA SilentlyContinue
$man = Join-Path $pkg.InstallLocation "AppxManifest.xml"
W "manifest: $(Test-Path $man)"
if (Test-Path $man) {
    try { Add-AppxPackage -Register $man -DisableDevelopmentMode -ForceApplicationShutdown -EA Stop; W "re-registered manifest" } catch { W "re-reg fail: $($_.Exception.Message)" }
}

W "`n=== may need reboot? check pending ==="
$pend = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
W "reboot pending: $pend"

W "DONE"
Copy-Item $log "\\Mac\Home\Downloads\vm-kb-verify.txt" -Force
