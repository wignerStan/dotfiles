$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\verify-debloat-log.txt"
"=== DEBLOAT VERIFICATION after reboot $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

W "── PACKAGE MANAGERS ──"
W "winget cmd: $([bool](Get-Command winget -EA SilentlyContinue))"
W "scoop cmd: $([bool](Get-Command scoop -EA SilentlyContinue))"
W "scoop dir: $(Test-Path "$env:USERPROFILE\scoop")"

W "`n── STORE / WINGET PACKAGES ──"
foreach($n in 'Microsoft.WindowsStore','Microsoft.StorePurchaseApp','Microsoft.DesktopAppInstaller'){
    $p = Get-AppxPackage -AllUsers -Name $n -EA SilentlyContinue
    W ("{0}: {1}" -f $n, $(if($p){"PRESENT ($($p.PackageFullName))"}else{'REMOVED'}))
}
$daFolder = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.29.280.0_arm64__8wekyb3d8bbwe"
W "AppInstaller folder: $(Test-Path $daFolder)"
W "winget cache (WinGet): $(Test-Path "$env:LOCALAPPDATA\Microsoft\WinGet")"
W "AppInstaller Appx data: $(Test-Path "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe")"

W "`n── DEFENDER (after reboot — did Tamper Protection re-enable it?) ──"
try {
    $rt = Get-MpPreference -EA SilentlyContinue
    W "realtime monitoring: $($rt.DisableRealtimeMonitoring)"
    W "behavior monitoring: $($rt.DisableBehaviorMonitoring)"
} catch { W "Get-MpPreference: $($_.Exception.Message)" }
$wd = Get-Service WinDefend -EA SilentlyContinue
W "WinDefend service: $(if($wd){$wd.Status+'/'+$wd.StartType}else{'absent'})"
W "Defender TamperProtection reg: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name TamperProtection -EA SilentlyContinue).TamperProtection)"
W "Defender DisableAntiSpyware reg: $((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Name DisableAntiSpyware -EA SilentlyContinue).DisableAntiSpyware)"

W "`n── FIREWALL ──"
$fw = (& netsh advfirewall show allprofiles state 2>&1 | Out-String)
foreach($l in ($fw -split "`n")){ if($l -match 'Profile|State'){ W ("  "+$l.Trim()) } }

W "`n── BACKEND SERVICES (should be Disabled) ──"
$svcs = @('WSearch','SysMain','DiagTrack','dmwappushservice','Spooler','bthserv','PhoneSvc','WbioSrvc','SensorService','WdNisSvc','WinDefend','WdBoot','XblGameSave')
foreach($s in $svcs){ $sv=Get-Service $s -EA SilentlyContinue; if($sv){ W ("  {0}: {1}/{2}" -f $s,$sv.Status,$sv.StartType) } else { W ("  ${s}: absent") } }

W "`n── TOOLS (simple tier — uv present, no mamba) ──"
foreach($t in 'uv','git','micromamba'){ W ("  ${t}: "+[bool](Get-Command $t -EA SilentlyContinue)) }
W "mamba root dir: $(Test-Path "$env:USERPROFILE\mamba")"
W "MAMBA_ROOT_PREFIX var: $([Environment]::GetEnvironmentVariable('MAMBA_ROOT_PREFIX','User'))"
W "pip cache: $(Test-Path "$env:LOCALAPPDATA\pip\cache")"

W "`n── DISK ──"
W ("C free: {0:N1} GB / used {1:N1} GB" -f ((Get-PSDrive C).Free/1GB),((Get-PSDrive C).Used/1GB))

W "`nDONE"