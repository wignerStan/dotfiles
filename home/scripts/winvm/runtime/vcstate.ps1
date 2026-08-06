Write-Host "--- SysWOW64 vc90 dlls ---"
Get-ChildItem C:\Windows\SysWOW64\msvc*90.dll, C:\Windows\SysWOW64\mfc*90.dll -EA SilentlyContinue | Select-Object -ExpandProperty Name
Write-Host "--- uninstall keys mentioning 2008/9.0 ---"
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' -EA SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -EA SilentlyContinue).DisplayName
    if ($d -match '2008|9\.0\.') { Write-Host $d }
}
Write-Host "--- WOW6432Node ---"
Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -EA SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -EA SilentlyContinue).DisplayName
    if ($d -match '2008|9\.0\.') { Write-Host $d }
}
