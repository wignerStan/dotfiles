$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\reg2-log.txt"
Add-Content $log "register.bat re-run"
cmd /c 'cd /d "C:\Weisoft Stock(x64)" && call register.bat' 2>&1 | Out-String | % { Add-Content $log $_ }
# check COM registration for key DLLs
foreach ($dll in @('COfficeDialog.dll','NTOnly.dll','XMessageBox.dll','WSInputBox.dll')) {
    $reg = reg query "HKCR\CLSID" /s /f $dll /d 2>$null
    $found = ($reg | Select-String $dll | Measure-Object).Count
    Add-Content $log ("CLSID for {0}: {1} hits" -f $dll, $found)
}
Add-Content $log "DONE"