$log = 'C:\Users\jacob\webview2-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "webview2 restore"
if (-not (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView')) {
    robocopy 'X:\Program Files (x86)\Microsoft\EdgeWebView' 'C:\Program Files (x86)\Microsoft\EdgeWebView' /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NP | Out-Null
    W ("WebView2 copied: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView\Application\150.0.4078.105\msedgewebview2.exe'))
} else { W "WebView2 already present" }
# 2. registry client key from old SOFTWARE hive
reg load "HKLM\OLD" 'X:\Windows\System32\config\SOFTWARE' 2>&1 | Out-Null
$clientKey = 'HKLM\OLD\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
$pv = (reg query $clientKey /v pv 2>$null | Select-String 'REG_SZ' | Out-String).Trim()
W ("old client pv: {0}" -f $pv)
if ($pv -match 'REG_SZ\s+(.+)') {
    $ver = $Matches[1]
    reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv /t REG_SZ /d $ver /f 2>&1 | Out-Null
    reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v name /t REG_SZ /d "Microsoft Edge WebView2 Runtime" /f 2>&1 | Out-Null
    W "client key restored with pv=$ver"
}
reg unload "HKLM\OLD" 2>&1 | Out-Null
W "DONE"
