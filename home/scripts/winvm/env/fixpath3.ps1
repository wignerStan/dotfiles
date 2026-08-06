$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\fixpath3-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "path fix v3"
$joined = "$H\.local\mingit\cmd;$H\.local\mingit\mingw64\bin;$H\.local\uv;$H\AppData\Local\7-Zip;$H\AppData\Local\GeekUninstaller"
reg load "HKU\$U" "$H\NTUSER.DAT" 2>&1 | Out-Null
try {
    Set-ItemProperty -Path "Registry::HKU\$U\Environment" -Name 'Path' -Value $joined -Type ExpandString -EA Stop
    W "Set-ItemProperty OK"
} catch { W "Set-ItemProperty FAIL: $($_.Exception.Message)" }
$check = (Get-ItemProperty "Registry::HKU\$U\Environment" -Name Path -EA SilentlyContinue).Path
W "verify: [$check]"
reg unload "HKU\$U" 2>&1 | Out-Null
W "DONE"