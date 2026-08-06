$ErrorActionPreference = 'Continue'
$log = 'C:\Users\jacob\hive-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "hive import start"
$hive = 'C:\Users\jacob\NTUSER.DAT'
reg load "HKU\JACOB" "$hive" 2>&1 | Out-String | % { W $_ }
# chunks: AppDataLow, Classes, all regMS-* except SystemCertificates
$files = @(
    '\\Mac\Home\reg-AppDataLow.reg',
    '\\Mac\Home\reg-Classes.reg'
)
$ms = Get-ChildItem '\\Mac\Home\regMS-*.reg' | Where-Object { $_.Name -notmatch 'SystemCertificates' } | Select-Object -ExpandProperty FullName
$files += $ms
foreach ($f in $files) {
    W "== $f"
    # rewrite HKCU -> HKU\JACOB
    $lines = Get-Content $f
    $out = foreach ($l in $lines) { $l -replace 'HKEY_CURRENT_USER', 'HKEY_USERS\JACOB' }
    $tmp = 'C:\Users\jacob\hive-tmp.reg'
    Set-Content $tmp $out -Encoding Unicode
    reg import $tmp 2>&1 | Out-String | % { W ("  " + $_.Trim()) }
}
reg unload "HKU\JACOB" 2>&1 | Out-String | % { W $_ }
W "DONE"
