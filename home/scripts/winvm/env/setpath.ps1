$joined = 'C:\Users\jacob\.local\mingit\cmd;C:\Users\jacob\.local\mingit\mingw64\bin;C:\Users\jacob\.local\uv;C:\Users\jacob\AppData\Local\7-Zip;C:\Users\jacob\AppData\Local\GeekUninstaller'
[Environment]::SetEnvironmentVariable('Path', $joined, 'User')
Add-Content 'C:\Users\jacob\setpath-log.txt' ("PATH set in interactive session: " + [Environment]::GetEnvironmentVariable('Path','User'))
# restart explorer so new processes get the fresh env
Stop-Process -Name explorer -Force -EA SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
Add-Content 'C:\Users\jacob\setpath-log.txt' "explorer restarted"
