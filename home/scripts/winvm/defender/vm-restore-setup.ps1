$ErrorActionPreference = "SilentlyContinue"
$log = "C:\Users\jacob\Downloads\defender-disable-log.txt"
"=== Defender permanent disable $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8

function W($m) { Add-Content -Path $log -Value $m }

# 1. Check Tamper Protection status
W "=== Tamper Protection ==="
$tp = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name TamperProtection -EA SilentlyContinue
W "TamperProtection reg: $($tp.TamperProtection)"

# 2. Disable Real-time Protection
W "`n=== Disable Real-time Protection ==="
Set-MpPreference -DisableRealtimeMonitoring $true 2>&1 | Out-Null
$rtp = (Get-MpPreference).DisableRealtimeMonitoring
W "DisableRealtimeMonitoring: $rtp"

# 3. Disable all Defender features
W "`n=== Disable Defender features ==="
Set-MpPreference -DisableBehaviorMonitoringSystem $true 2>&1 | Out-Null
Set-MpPreference -DisableBlockAtFirstSeen $true 2>&1 | Out-Null
Set-MpPreference -DisableIOAVProtection $true 2>&1 | Out-Null
Set-MpPreference -DisableIntrusionPreventionSystem $true 2>&1 | Out-Null
Set-MpPreference -DisableScriptScanning $true 2>&1 | Out-Null
Set-MpPreference -DisableArchiveScanning $true 2>&1 | Out-Null
Set-MpPreference -DisableEmailScanning $true 2>&1 | Out-Null
Set-MpPreference -DisableRemovableDriveScanning $true 2>&1 | Out-Null
W "MpPreference set done"

# 4. Set Defender services to disabled (Start=4)
W "`n=== Disable Defender services ==="
$services = @("WinDefend", "WdNisSvc", "Sense")
foreach ($svc in $services) {
    $current = (Get-Service $svc -EA SilentlyContinue).Status
    $startType = (Get-Service $svc -EA SilentlyContinue).StartType
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\$svc" /v Start /t REG_DWORD /d 4 /f 2>&1 | Out-Null
    $newStart = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -EA SilentlyContinue).Start
    W "$svc : was $current/$startType -> Start=$newStart"
}

# 5. Disable Defender scheduled tasks
W "`n=== Disable Defender tasks ==="
$tasks = Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.TaskPath -like "*Microsoft*Windows*Defender*" }
foreach ($t in $tasks) {
    Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath 2>&1 | Out-Null
    W "disabled: $($t.TaskPath)$($t.TaskName)"
}

# 6. Disable via registry (belt and suspenders)
W "`n=== Registry hardening ==="
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f 2>&1 | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f 2>&1 | Out-Null
W "policy registry set"

# 7. Verify
W "`n=== Verify ==="
$mpStatus = Get-MpComputerStatus -EA SilentlyContinue
W "AMRunningMode: $($mpStatus.AMRunningMode)"
W "RealTimeProtectionEnabled: $($mpStatus.RealTimeProtectionEnabled)"
W "BehaviorMonitorEnabled: $($mpStatus.BehaviorMonitorEnabled)"
W "AntispywareEnabled: $($mpStatus.AntispywareEnabled)"
W "AntivirusEnabled: $($mpStatus.AntivirusEnabled)"

# 8. Check Windows Security UI state
W "`n=== Security UI ==="
$sechealth = Get-AppxPackage -Name "*SecHealth*" -EA SilentlyContinue
W "SecHealthUI: $($sechealth.Name) $($sechealth.Version)"
$secCenter = Get-AppxPackage -Name "*DefenderSecurity*" -EA SilentlyContinue
W "SecurityCenter: $($secCenter.Name)"

W "`nDONE"
