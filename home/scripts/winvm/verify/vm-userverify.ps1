Write-Host "=== .ssh ==="
Get-ChildItem C:\Users\jacob\.ssh -EA SilentlyContinue | Select-Object Name | ForEach-Object { Write-Host ("  " + $_.Name) }
Write-Host "ssh_config_exists=" + (Test-Path C:\Users\jacob\.ssh\config)
Write-Host "=== chezmoi refs ==="
Write-Host "chezmoi.toml.vm-backup=" + (Test-Path C:\Users\jacob\.config\chezmoi\chezmoi.toml.vm-backup)
Write-Host "chezmoi.toml=" + (Test-Path C:\Users\jacob\.config\chezmoi\chezmoi.toml)
Write-Host "=== jzt/Weisoft ==="
Write-Host "WinStock=" + (Test-Path 'C:\Weisoft Stock(x64)\WinStock.exe')
Write-Host "=== profile scripts ==="
Get-ChildItem C:\Users\jacob -Filter *.ps1 -ErrorAction SilentlyContinue | Measure-Object | ForEach-Object { Write-Host ("ps1_count=" + $_.Count) }
Get-ChildItem C:\Users\jacob\MicrosoftProfile.ps1,C:\Users\jacob\profile.ps1 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("profile:" + $_.Name) }
