$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
Write-Host "--- .ssh ---"
cmd /c dir /b $H\.ssh 2>&1 | Out-String | Write-Host
Write-Host "--- .config\chezmoi ---"
cmd /c dir /b $H\.config\chezmoi 2>&1 | Out-String | Write-Host
Write-Host "--- Weisoft top ---"
cmd /c dir /b "C:\Weisoft Stock(x64)" 2>&1 | Out-String | Write-Host
Write-Host "--- jzt files (WinStock Data?) ---"
Test-Path "C:\Weisoft Stock(x64)\Data" | Write-Host