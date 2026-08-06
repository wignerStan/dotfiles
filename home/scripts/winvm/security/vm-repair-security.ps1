$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\repair-security-log.txt"
"=== repair Security UI registration $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# 1. DISM RestoreHealth — repairs the shield-provider component registration from the component store
W "=== DISM RestoreHealth (component-store repair) ==="
$r = & dism.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
W ($r -split "`n" | Select-Object -Last 6 | Out-String).Trim()

# 2. Re-register SecHealthUI from its real manifest (full, not stub)
W "`n=== re-register SecHealthUI ==="
$pkg = Get-AppxPackage -Name "Microsoft.SecHealthUI" -EA SilentlyContinue
$man = Join-Path $pkg.InstallLocation "AppxManifest.xml"
W "manifest: $(Test-Path $man)"
if (Test-Path $man) {
    try { Add-AppxPackage -Register $man -DisableDevelopmentMode -ForceApplicationShutdown -EA Stop; W "re-registered" }
    catch { W "fail: $($_.Exception.Message)" }
}

# 3. Restart the Security Health Service
W "`n=== restart service ==="
Restart-Service SecurityHealthService -Force -EA SilentlyContinue
Start-Sleep 3
W "SecurityHealthService: $((Get-Service SecurityHealthService -EA SilentlyContinue).Status)"

# 4. check the protocol now
$cmd = (Get-ItemProperty "HKLM:\SOFTWARE\Classes\windowsdefender\shell\open\command" -EA SilentlyContinue).'(default)'
W "protocol command: [$cmd]"

# 5. relaunch
W "`n=== relaunch ==="
Start-Process "windowsdefender://" -EA SilentlyContinue
Start-Sleep 6
$proc = Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -match "SecHealth|SecurityHealth" }
W "procs: $(if($proc){($proc|Select -ExpandProperty ProcessName) -join ','}else{'none'})"

W "DONE"
Copy-Item $log "\\Mac\Home\Downloads\vm-repair-security-log.txt" -Force