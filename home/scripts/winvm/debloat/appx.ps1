$log = 'C:\Users\jacob\appx-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "appx enum"
Get-AppxPackage -AllUsers -EA SilentlyContinue | Where-Object { $_.Name -match 'Edge|SecHealth|WebView' } | ForEach-Object {
    W ("{0} | {1} | {2}" -f $_.Name, $_.PackageFullName, $_.InstallLocation)
}
# EdgeUpdate dir contents
W "== EdgeUpdate dirs =="
Get-ChildItem 'C:\Program Files (x86)\Microsoft\EdgeUpdate' -Recurse -EA SilentlyContinue | Select-Object -First 10 | ForEach-Object { W ("  {0}" -f $_.FullName) }
Get-ChildItem 'C:\ProgramData\Microsoft\EdgeUpdate' -EA SilentlyContinue | Select-Object -First 5 | ForEach-Object { W ("  PD: {0}" -f $_.FullName) }
W "DONE"
