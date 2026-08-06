$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\tile-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "tile cleanup"
W "== Security shortcuts =="
Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Recurse -EA SilentlyContinue | Where-Object { $_.Name -match 'Security|安全|Defender' } | ForEach-Object {
    W ("  found: {0}" -f $_.FullName)
    Remove-Item $_.FullName -Force -EA SilentlyContinue
    W ("  removed: {0}" -f (-not (Test-Path $_.FullName)))
}
Get-ChildItem "$H\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" -Recurse -EA SilentlyContinue | Where-Object { $_.Name -match 'Security|安全|Defender' } | ForEach-Object {
    W ("  user found: {0}" -f $_.FullName)
    Remove-Item $_.FullName -Force -EA SilentlyContinue
}
W "== DevTools dir deep look =="
$dt = 'C:\Windows\SystemApps\Microsoft.MicrosoftEdgeDevToolsClient_8wekyb3d8bbwe'
if (Test-Path $dt) {
    icacls $dt 2>&1 | Select-Object -First 6 | ForEach-Object { W "  acl: $_" }
    Get-ChildItem $dt -Recurse -File -EA SilentlyContinue | Select-Object -First 8 | ForEach-Object { W ("  file: {0}" -f $_.FullName) }
    # try delete files individually
    Get-ChildItem $dt -Recurse -File -EA SilentlyContinue | ForEach-Object {
        try { Remove-Item $_.FullName -Force -ErrorAction Stop } catch { W ("  locked: {0}" -f $_.FullName) }
    }
    # then the dir
    try { Remove-Item -LiteralPath $dt -Recurse -Force -ErrorAction Stop; W "  dir removed" }
    catch { W "  dir fails: $($_.Exception.Message)" }
}
W "DONE"