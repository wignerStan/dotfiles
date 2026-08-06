$log = 'C:\Users\jacob\scanvc-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "vc90 ref scan"
$d = 'C:\Weisoft Stock(x64)'
$files = @('WinStock.exe','COfficeDialog.dll','FM20.DLL','GlobalCom.dll','NTOnly.dll','SmtpMail.dll','WSInputBox.dll','XMessageBox.dll','UI.dll','UIU.dll','Reg.dll','VBAInterpret.dll')
foreach ($f in $files) {
    $p = Join-Path $d $f
    if (-not (Test-Path $p)) { W ("{0}: MISSING" -f $f); continue }
    $bytes = [System.IO.File]::ReadAllBytes($p)
    $txt = [System.Text.Encoding]::ASCII.GetString($bytes)
    $refs = [regex]::Matches($txt, 'name="Microsoft\.VC90\.[A-Za-z]+" version="[0-9.]+" processorArchitecture="[a-z0-9]+"')
    if ($refs.Count -gt 0) {
        foreach ($r in $refs) { W ("{0}: {1}" -f $f, $r.Value) }
    } else { W ("{0}: no VC90 refs" -f $f) }
}
W "DONE"
