$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
Write-Host "=== .ssh ==="
Get-ChildItem $H\.ssh -EA SilentlyContinue | Select-Object Name | ForEach-Object { Write-Host ("  " + $_.Name) }
Write-Host "ssh_config_exists=" + (Test-Path $H\.ssh\config)
Write-Host "=== chezmoi refs ==="
Write-Host "chezmoi.toml.vm-backup=" + (Test-Path $H\.config\chezmoi\chezmoi.toml.vm-backup)
Write-Host "chezmoi.toml=" + (Test-Path $H\.config\chezmoi\chezmoi.toml)
Write-Host "=== jzt/Weisoft ==="
Write-Host "WinStock=" + (Test-Path 'C:\Weisoft Stock(x64)\WinStock.exe')
Write-Host "=== profile scripts ==="
Get-ChildItem $H -Filter *.ps1 -ErrorAction SilentlyContinue | Measure-Object | ForEach-Object { Write-Host ("ps1_count=" + $_.Count) }
Get-ChildItem $H\MicrosoftProfile.ps1,$H\profile.ps1 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("profile:" + $_.Name) }