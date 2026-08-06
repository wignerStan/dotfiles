$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$ErrorActionPreference = 'Continue'
$log = "$H\hive-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "hive import start"
$hive = "$H\NTUSER.DAT"
reg load "HKU\$U" "$hive" 2>&1 | Out-String | % { W $_ }
# chunks: AppDataLow, Classes, all regMS-* except SystemCertificates
$files = @(
    '\\Mac\Home\reg-AppDataLow.reg',
    '\\Mac\Home\reg-Classes.reg'
)
$ms = Get-ChildItem '\\Mac\Home\regMS-*.reg' | Where-Object { $_.Name -notmatch 'SystemCertificates' } | Select-Object -ExpandProperty FullName
$files += $ms
foreach ($f in $files) {
    W "== $f"
    # rewrite HKCU -> HKU\$U
    $lines = Get-Content $f
    $out = foreach ($l in $lines) { $l.Replace('HKEY_CURRENT_USER', "HKEY_USERS\$U") }
    $tmp = "$H\hive-tmp.reg"
    Set-Content $tmp $out -Encoding Unicode
    reg import $tmp 2>&1 | Out-String | % { W ("  " + $_.Trim()) }
}
reg unload "HKU\$U" 2>&1 | Out-String | % { W $_ }
W "DONE"