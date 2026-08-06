$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\find-sechealth-log.txt"
"=== find SecHealthClient source to restore $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# 1. WinSxS component store has the staged Appx packages — search for SecHealthClient
W "=== WinSxS search ==="
$wsx = Get-ChildItem "C:\Windows\WinSxS" -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "SecHealthClient|WindowsDefenderSecurityCenter|DefenderSecurity" }
if ($wsx) { $wsx | ForEach-Object { W "  $($_.Name)" } } else { W "  none in WinSxS" }

# 2. Any AppxManifest on disk for it?
W "`n=== AppxManifest search ==="
$man = Get-ChildItem "C:\Windows" -Recurse -Filter "AppxManifest.xml" -EA SilentlyContinue -Depth 3 | Where-Object { $_.FullName -match "SecHealth|DefenderSecurity" } | Select-Object -First 5
foreach ($m in $man) { W "  $($m.FullName)" }
if (-not $man) { W "  no manifest found" }

# 3. Try DISM to get the staged package list (online)
W "`n=== DISM staged packages ==="
$dism = & dism.exe /Online /Get-ProvisionedAppxPackages 2>&1 | Out-String
$matches = ($dism -split "`n") | Where-Object { $_ -match "SecHealth|Defender" }
if ($matches) { $matches | ForEach-Object { W "  $($_.Trim())" } } else { W "  DISM: no SecHealth staged" }

# 4. Can we launch Windows Security directly (the exe)?
W "`n=== direct exe ==="
foreach ($exe in @("C:\Program Files\Windows Defender\WindowsDefenderSecurityCenter.exe","C:\Windows\SystemApps\Microsoft.WindowsDefenderSecurityCenter_8wekyb3d8bbwe\SecurityHealthService.exe")) {
    W "  $exe : $(Test-Path $exe)"
}
W "SecurityHealthSettingsHost: $(Test-Path 'C:\Windows\System32\SecurityHealthSystray.exe')"
W "DONE"