$checks = @(
  "C:\Users\jacob\.ssh\id_chezmoi.pub",
  "C:\Users\jacob\.ssh\config.vm-backup",
  "C:\Users\jacob\AppData\Roaming\chezmoi\chezmoi.toml",
  "C:\Weisoft\Stock(x64)\WinStock.exe",
  "C:\Weisoft\Stock(x64)\Data"
)
foreach ($p in $checks) { Write-Output ("{0} => {1}" -f $p, (Test-Path $p)) }
Write-Output "---- volumes ----"
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -in 'C','Z','Y'} | ForEach-Object { "{0}: used={1:N0} free={2:N0}" -f $_.Name,$_.Used,$_.Free }
Write-Output "---- snapshots guest-side (non-authoritative) ----"
Write-Output ("winver host checks: " + (Get-Item C:\Windows\System32\winver.exe).VersionInfo.FileVersion)
