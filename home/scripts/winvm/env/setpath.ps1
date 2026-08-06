$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$joined = "$H\.local\mingit\cmd;$H\.local\mingit\mingw64\bin;$H\.local\uv;$H\AppData\Local\7-Zip;$H\AppData\Local\GeekUninstaller"
[Environment]::SetEnvironmentVariable('Path', $joined, 'User')
Add-Content "$H\setpath-log.txt" ("PATH set in interactive session: " + [Environment]::GetEnvironmentVariable('Path','User'))
# restart explorer so new processes get the fresh env
Stop-Process -Name explorer -Force -EA SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
Add-Content "$H\setpath-log.txt" "explorer restarted"