Write-Host "--- .ssh ---"
cmd /c dir /b C:\Users\jacob\.ssh 2>&1 | Out-String | Write-Host
Write-Host "--- .config\chezmoi ---"
cmd /c dir /b C:\Users\jacob\.config\chezmoi 2>&1 | Out-String | Write-Host
Write-Host "--- Weisoft top ---"
cmd /c dir /b "C:\Weisoft Stock(x64)" 2>&1 | Out-String | Write-Host
Write-Host "--- jzt files (WinStock Data?) ---"
Test-Path "C:\Weisoft Stock(x64)\Data" | Write-Host
