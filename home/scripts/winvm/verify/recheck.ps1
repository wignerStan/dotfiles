$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\recheck-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "post-reboot recheck"
W ("Edge.Stable: {0}" -f [bool](Get-AppxPackage -AllUsers -EA SilentlyContinue *MicrosoftEdge.Stable*))
W ("SecHealthUI: {0}" -f [bool](Get-AppxPackage -AllUsers -EA SilentlyContinue *SecHealthUI*))
W ("EdgeDevToolsClient: {0}" -f [bool](Get-AppxPackage -AllUsers -EA SilentlyContinue *EdgeDevTools*))
W ("appx total: {0}" -f (Get-AppxPackage -AllUsers -EA SilentlyContinue).Count)
W ("msedge: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'))
W ("EdgeUpdate PF: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeUpdate'))
W ("EdgeUpdate PD: {0}" -f (Test-Path 'C:\ProgramData\Microsoft\EdgeUpdate'))
W ("SecHealthUI files: {0}" -f [bool](Get-ChildItem 'C:\Program Files\WindowsApps' -Directory -Filter '*SecHealthUI*' -EA SilentlyContinue))
W ("DevTools files: {0}" -f (Test-Path 'C:\Windows\SystemApps\Microsoft.MicrosoftEdgeDevToolsClient_8wekyb3d8bbwe'))
W "DONE"