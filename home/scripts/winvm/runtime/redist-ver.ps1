$log = 'C:\Users\jacob\redist-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "redist version"
$vi = (Get-Item 'C:\Weisoft Stock(x64)\vcredist_x86.exe').VersionInfo
W ("FileVersion: {0}" -f $vi.FileVersion)
W ("ProductVersion: {0}" -f $vi.ProductVersion)
# check embedded manifest of the failing exes for version requests
foreach ($h in @('RestartServies.exe','PoboQuotService.exe','ComDll.exe','FrontAddress.exe')) {
    $bytes = [System.IO.File]::ReadAllBytes("C:\Weisoft Stock(x64)\$h")
    $txt = [System.Text.Encoding]::ASCII.GetString($bytes)
    $m = [regex]::Match($txt, 'name="Microsoft\.VC90\.(CRT|ATL|MFC|OpenMP)" version="([0-9.]+)" processorArchitecture="([^"]+)"')
    $m2 = [regex]::Match($txt, 'name="Microsoft\.VC90\.(CRT|ATL|MFC|OpenMP)"[^>]{0,80}version="([0-9.]+)"')
    W ("{0}: {1}" -f $h, $m2.Value)
    $all = [regex]::Matches($txt, 'Microsoft\.VC90\.[A-Za-z]+" version="[0-9.]+" processorArchitecture="[a-z0-9]+"')
    foreach ($a in $all) { W ("    req: {0}" -f $a.Value) }
}
W "DONE"
