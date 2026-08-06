$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\disable-backend-log.txt"
"=== disable Defender + firewall + backend services $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# ── Windows Defender: disable realtime + cloud + the engine ──
W "=== Defender ==="
# Tamper Protection may block Set-MpPreference; set the registry keys too.
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -EA SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -EA SilentlyContinue
    Set-MpPreference -DisableScriptScanning $true -EA SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -EA SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $true -EA SilentlyContinue
    Set-MpPreference -DisableIntrusionPreventionSystem $true -EA SilentlyContinue
    Set-MpPreference -EnableControlledFolderAccess Disabled -EA SilentlyContinue
    Set-MpPreference -SubmitSamplesConsent NeverSend -EA SilentlyContinue
    Set-MpPreference -MAPSReporting Disabled -EA SilentlyContinue
    Set-MpPreference -SpynetReporting Disabled -EA SilentlyContinue
    W "  Set-MpPreference: realtime/etc disabled"
} catch { W "  Set-MpPreference error: $($_.Exception.Message)" }
# registry: disable Defender realtime (Tamper-Protection-friendly backup)
$mp = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
New-Item -Path $mp -Force -EA SilentlyContinue | Out-Null
Set-ItemProperty -Path $mp -Name "DisableAntiSpyware" -Value 1 -Type DWord -EA SilentlyContinue
Set-ItemProperty -Path $mp -Name "DisableRoutinelyTakingAction" -Value 1 -Type DWord -EA SilentlyContinue
$rt = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
New-Item -Path $rt -Force -EA SilentlyContinue | Out-Null
Set-ItemProperty -Path $rt -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -EA SilentlyContinue
W "  registry Defender-disable keys set"

# ── Firewall: all profiles off ──
W "`n=== Firewall ==="
& netsh.exe advfirewall set allprofiles state off 2>&1 | ForEach-Object { W "  $_" }

# ── Backend services: disable (stop + set Disabled) ──
W "`n=== Backend services ==="
$svcs = @(
    'WSearch','SysMain','DiagTrack','dmwappushservice','WMPNetworkSvc',
    'Spooler','Fax',
    'XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc',
    'bthserv','PhoneSvc','WbioSrvc','SensorService',
    'WdNisSvc','WinDefend','Sense','WdBoot'   # Defender backend services
)
foreach ($s in $svcs) {
    $svc = Get-Service -Name $s -EA SilentlyContinue
    if (-not $svc) { W "  $s : not present"; continue }
    try {
        Stop-Service -Name $s -Force -EA SilentlyContinue
        Set-Service -Name $s -StartupType Disabled -EA SilentlyContinue
        W "  ${s}: stopped + Disabled (was $($svc.Status)/$($svc.StartType))"
    } catch {
        # some services refuse Set-Service; try sc.exe
        & sc.exe config $s start= disabled 2>&1 | Out-Null
        & sc.exe stop $s 2>&1 | Out-Null
        W "  ${s}: via sc.exe (may be protected)"
    }
}

# ── Defender Tamper Protection off (allows the above to stick) ──
W "`n=== Tamper Protection ==="
$tp = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
Set-ItemProperty -Path $tp -Name "TamperProtection" -Value 0 -Type DWord -EA SilentlyContinue
W "  TamperProtection = 0 (may require reboot to fully apply)"

W "`nDONE"
"C free: {0:N1} GB" -f ((Get-PSDrive C).Free/1GB) | Add-Content -Path $log -Encoding UTF8