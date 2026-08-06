$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
Write-Host "=== Edge remnants ==="
Write-Host ("msedge.exe: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'))
Write-Host ("Edge dir: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\Edge'))
Write-Host ("EdgeWebView: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView'))
Write-Host ("EdgeCore: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeCore'))
Write-Host "=== Edge appx ==="
Get-AppxPackage -AllUsers -EA SilentlyContinue *Edge* | Select-Object -ExpandProperty Name
Write-Host "=== SecHealthUI ==="
Get-AppxPackage -AllUsers -EA SilentlyContinue *SecHealth* | Select-Object -ExpandProperty PackageFullName
if (Test-Path 'C:\Windows\SystemApps\Microsoft.SecHealthUI_*') { Write-Host "SecHealthUI SystemApps dir present" } else { Write-Host "SecHealthUI dir absent" }
Write-Host "=== appx count ==="
Write-Host ((Get-AppxPackage -AllUsers -EA SilentlyContinue).Count)
Write-Host "=== Win11Debloat log tail ==="
Get-Content "$H\.local\win11debloat\Logs\Win11Debloat.log" -Tail 15 -EA SilentlyContinue