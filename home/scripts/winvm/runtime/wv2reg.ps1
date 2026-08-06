$log = 'C:\Users\jacob\wv2reg-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "wv2 registry"
reg load "HKLM\OLD" 'X:\Windows\System32\config\SOFTWARE' 2>&1 | Out-Null
foreach ($base in @('HKLM\OLD\Microsoft\EdgeUpdate\Clients','HKLM\OLD\WOW6432Node\Microsoft\EdgeUpdate\Clients')) {
    $k = "$base\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    $pv = (reg query $k /v pv 2>$null | Select-String 'REG_SZ' | Out-String).Trim()
    if ($pv -match 'REG_SZ\s+(.+)') {
        $ver = $Matches[1]
        W ("found pv={0} at {1}" -f $ver, $base)
        reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv /t REG_SZ /d $ver /f 2>&1 | Out-Null
        reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v name /t REG_SZ /d "Microsoft Edge WebView2 Runtime" /f 2>&1 | Out-Null
        W "restored"
        break
    }
}
reg unload "HKLM\OLD" 2>&1 | Out-Null
W "DONE"
