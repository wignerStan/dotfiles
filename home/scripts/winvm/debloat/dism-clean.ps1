$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$ErrorActionPreference = 'Continue'
$log = "$H\dism-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "dism cleanup"
W "== provisioned packages (SecHealth/EdgeDevTools) =="
$prov = dism /online /english /get-provisionedappxpackages 2>&1
$prov | Select-String -Pattern 'SecHealth|EdgeDevTools' -Context 1,1 | ForEach-Object { W "  $_" }
# find full package names
$names = $prov | Select-String -Pattern 'PackageName : Microsoft\.(SecHealthUI|MicrosoftEdgeDevToolsClient)[^\r\n]*'
foreach ($m in $names) {
    $pn = ($m.Line -split ':', 2)[1].Trim()
    W "removing provisioned: $pn"
    dism /online /english /remove-provisionedappxpackage /packagename:"$pn" 2>&1 | Select-String 'operation|successful|error' | ForEach-Object { W "  $_" }
}
W "== retry file deletes =="
$dt = 'C:\Windows\SystemApps\Microsoft.MicrosoftEdgeDevToolsClient_8wekyb3d8bbwe'
if (Test-Path $dt) {
    try { Remove-Item -LiteralPath $dt -Recurse -Force -ErrorAction Stop; W "  DevTools dir removed" }
    catch { W "  DevTools dir STILL fails: $($_.Exception.Message)" }
}
$sec = Get-ChildItem 'C:\Program Files\WindowsApps' -Directory -Filter '*SecHealthUI*' -EA SilentlyContinue
foreach ($d in $sec) {
    try { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop; W "  SecHealthUI dir removed" }
    catch { W "  SecHealthUI dir fails: $($_.Exception.Message)" }
}
W "== after =="
W ("SecHealthUI: {0}" -f [bool](Get-AppxPackage -AllUsers -EA SilentlyContinue *SecHealthUI*))
W ("EdgeDevToolsClient: {0}" -f [bool](Get-AppxPackage -AllUsers -EA SilentlyContinue *EdgeDevTools*))
W ("DevTools files: {0}" -f (Test-Path $dt))
W "DONE"