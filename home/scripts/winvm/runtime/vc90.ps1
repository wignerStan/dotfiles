$log = 'C:\Users\jacob\vc90-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "vc90 copy + x86 registration"
$d = 'C:\Weisoft Stock(x64)'
$dlls = @('msvcr90.dll','msvcp90.dll','msvcm90.dll','mfc90.dll','mfc90u.dll','vcomp90.dll','atl90.dll')
foreach ($f in $dlls) {
    $src = Join-Path $d $f
    if (Test-Path $src) {
        Copy-Item $src "C:\Windows\SysWOW64\$f" -Force -EA SilentlyContinue
        W ("copied {0}: {1}" -f $f, (Test-Path "C:\Windows\SysWOW64\$f"))
    } else { W ("{0} not in dir" -f $f) }
}
# retry x86 registration
foreach ($f in @('EDITGRIDCTRLLIB.OCX','EditGridLib.ocx','MSHFlexGridPrint.dll')) {
    $p = Join-Path $d $f
    & 'C:\Windows\SysWOW64\regsvr32.exe' /s $p
    W ("regsvr32 {0} exit={1}" -f $f, $LASTEXITCODE)
}
foreach ($f in @('EditGridLib.ocx','EDITGRIDCTRLLIB.OCX','MSHFlexGridPrint.dll')) {
    $hits = (reg query "HKCR\CLSID" /s /f $f /d 2>$null | Select-String $f | Measure-Object).Count
    W ("CLSID hits {0}: {1}" -f $f, $hits)
}
W "DONE"
