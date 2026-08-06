$log = "C:\Users\jacob\Downloads\defender-bootfix-log.txt"
"=== Defender boot-time disable task $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# The disable-once script that runs at every boot.
$script = @'
$ErrorActionPreference = 'SilentlyContinue'
# re-apply Defender disable (it self-heals on reboot)
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableScriptScanning $true
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisableBlockAtFirstSeen $true
Set-MpPreference -DisableIntrusionPreventionSystem $true
Set-MpPreference -EnableControlledFolderAccess Disabled
Set-MpPreference -SubmitSamplesConsent NeverSend
Set-MpPreference -MAPSReporting Disabled
Set-MpPreference -AllowDatagramProcessingOnWinServer $true
# stop the services if they restarted
foreach ($s in 'WinDefend','WdNisSvc','WdBoot') { try { Stop-Service $s -Force -EA SilentlyContinue; Set-Service $s -StartupType Disabled -EA SilentlyContinue } catch {} }
'@

$dest = "C:\ProgramData\Scripts\DisableDefender.ps1"
New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
$script | Out-File -FilePath $dest -Encoding UTF8
W "disable script: $dest"

# Register a task that runs at every boot (AtStartup), as SYSTEM, highest.
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$dest`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'DisableDefenderAtBoot' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
W "registered boot task: DisableDefenderAtBoot"

# run it once now so the current session is also disabled
& $dest 2>&1 | Out-Null
W "ran once now"

W "`n=== immediate verify ==="
$rt = Get-MpPreference -EA SilentlyContinue
W "realtime: $($rt.DisableRealtimeMonitoring)"
W "behavior: $($rt.DisableBehaviorMonitoring)"
$wd = Get-Service WinDefend -EA SilentlyContinue
W "WinDefend: $(if($wd){$wd.Status+'/'+$wd.StartType}else{'-'})"
W "DONE"
