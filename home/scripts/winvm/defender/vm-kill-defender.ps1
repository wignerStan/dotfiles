$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\kill-defender-log.txt"
"=== kill Defender (persist across reboot) $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# 1. Tamper Protection OFF (in its own protected path; SYSTEM can write it)
$tp = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
try { Set-ItemProperty -Path $tp -Name TamperProtection -Value 0 -Type DWord -Force -EA Stop; W "TamperProtection -> 0" }
catch { W "TamperProtection fail: $($_.Exception.Message)" }

# 2. GPO DisableAntiSpyware (Defender respects this even with Tamper on, post-reboot)
$mp = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
New-Item -Path $mp -Force -EA SilentlyContinue | Out-Null
Set-ItemProperty -Path $mp -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -EA SilentlyContinue
Set-ItemProperty -Path $mp -Name "DisableRoutinelyTakingAction" -Value 1 -Type DWord -Force -EA SilentlyContinue
$rt = "$mp\Real-Time Protection"
New-Item -Path $rt -Force -EA SilentlyContinue | Out-Null
Set-ItemProperty -Path $rt -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force -EA SilentlyContinue
Set-ItemProperty -Path $rt -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force -EA SilentlyContinue
Set-ItemProperty -Path $rt -Name "DisableOnAccessProtection" -Value 1 -Type DWord -Force -EA SilentlyContinue
Set-ItemProperty -Path $rt -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force -EA SilentlyContinue
W "GPO Defender-disable keys set"

# 3. Services: set Start=4 (Disabled) in the Services registry key — reboot-persistent,
#    and Defender can't easily self-heal a Start=4 here (unlike Set-Service).
foreach ($s in 'WinDefend','WdNisSvc','WdBoot','Sense','WdSysHealth') {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$s"
    if (Test-Path $k) {
        try {
            Set-ItemProperty -Path $k -Name "Start" -Value 4 -Type DWord -Force -EA Stop
            W "$s Start -> 4 (Disabled)"
        } catch { W "$s Start fail: $($_.Exception.Message)" }
    }
}

# 4. also disable via sc (belt-and-suspenders, in case registry perms differ)
foreach ($s in 'WinDefend','WdNisSvc','WdBoot'){ & sc.exe config $s start= disabled 2>&1 | Out-Null }

# verify what we just set (before reboot self-heal)
W "`n=== immediate verify ==="
W "TamperProtection: $((Get-ItemProperty $tp -Name TamperProtection -EA SilentlyContinue).TamperProtection)"
W "DisableAntiSpyware: $((Get-ItemProperty $mp -Name DisableAntiSpyware -EA SilentlyContinue).DisableAntiSpyware)"
W "WinDefend Start: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name Start -EA SilentlyContinue).Start)"
W "WinDefend service: $((Get-Service WinDefend -EA SilentlyContinue).Status)/$((Get-Service WinDefend -EA SilentlyContinue).StartType)"
W "DONE"