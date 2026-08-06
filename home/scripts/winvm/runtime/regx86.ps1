$log = 'C:\Users\jacob\regx86-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "x86 regsvr32 registration"
$d = 'C:\Weisoft Stock(x64)'
$files = @('EDITGRIDCTRLLIB.OCX','EditGridLib.ocx','MSHFlexGridPrint.dll')
foreach ($f in $files) {
    $p = Join-Path $d $f
    W "== $f"
    $out = & 'C:\Windows\SysWOW64\regsvr32.exe' /s $p 2>&1
    $code = $LASTEXITCODE
    W ("  exit={0} {1}" -f $code, ($out -join ' '))
}
# verify via CLSID search
foreach ($f in @('EditGridLib.ocx','EDITGRIDCTRLLIB.OCX')) {
    $hits = (reg query "HKCR\CLSID" /s /f $f /d 2>$null | Select-String $f | Measure-Object).Count
    W ("CLSID hits for {0}: {1}" -f $f, $hits)
}
W "DONE"
