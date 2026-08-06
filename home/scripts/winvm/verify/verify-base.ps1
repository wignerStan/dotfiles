Write-Host "--- appx count ---"
Write-Host ((Get-AppxPackage -AllUsers).Count)
Write-Host "--- Edge remnants ---"
Write-Host ("msedge.exe: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'))
Write-Host ("EdgeWebView: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView'))
Write-Host ("EdgeCore: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeCore'))
Write-Host "--- SecHealthUI ---"
Get-AppxPackage -AllUsers *SecHealth* | Select-Object -ExpandProperty PackageFullName
Write-Host "--- chezmoi remnants (should be gone) ---"
Write-Host ("mingit: {0}" -f (Test-Path "$env:USERPROFILE\.local\mingit"))
Write-Host ("weisoft: {0}" -f (Test-Path 'C:\Weisoft Stock(x64)'))
Write-Host "--- defender ---"
$mp = Get-MpPreference
Write-Host ("RealTimeProtection disabled: {0}" -f $mp.DisableRealtimeMonitoring)
