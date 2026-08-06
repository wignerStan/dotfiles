$log = 'C:\Users\jacob\fixpath3-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "path fix v3"
$joined = 'C:\Users\jacob\.local\mingit\cmd;C:\Users\jacob\.local\mingit\mingw64\bin;C:\Users\jacob\.local\uv;C:\Users\jacob\AppData\Local\7-Zip;C:\Users\jacob\AppData\Local\GeekUninstaller'
reg load "HKU\JACOB" 'C:\Users\jacob\NTUSER.DAT' 2>&1 | Out-Null
try {
    Set-ItemProperty -Path 'Registry::HKU\JACOB\Environment' -Name 'Path' -Value $joined -Type ExpandString -EA Stop
    W "Set-ItemProperty OK"
} catch { W "Set-ItemProperty FAIL: $($_.Exception.Message)" }
$check = (Get-ItemProperty 'Registry::HKU\JACOB\Environment' -Name Path -EA SilentlyContinue).Path
W "verify: [$check]"
reg unload "HKU\JACOB" 2>&1 | Out-Null
W "DONE"
