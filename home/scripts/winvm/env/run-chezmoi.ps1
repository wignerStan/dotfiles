$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$env:HOME = "$H"
$env:USERPROFILE = "$H"
$env:APPDATA = "$H\AppData\Roaming"
$env:LOCALAPPDATA = "$H\AppData\Local"
& "$H\.local\chezmoi\chezmoi.exe" @args
exit $LASTEXITCODE