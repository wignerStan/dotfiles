$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$checks = @(
  "$H\.ssh\id_chezmoi.pub",
  "$H\.ssh\config.vm-backup",
  "$H\AppData\Roaming\chezmoi\chezmoi.toml",
  "C:\Weisoft\Stock(x64)\WinStock.exe",
  "C:\Weisoft\Stock(x64)\Data"
)
foreach ($p in $checks) { Write-Output ("{0} => {1}" -f $p, (Test-Path $p)) }
Write-Output "---- volumes ----"
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -in 'C','Z','Y'} | ForEach-Object { "{0}: used={1:N0} free={2:N0}" -f $_.Name,$_.Used,$_.Free }
Write-Output "---- snapshots guest-side (non-authoritative) ----"
Write-Output ("winver host checks: " + (Get-Item C:\Windows\System32\winver.exe).VersionInfo.FileVersion)