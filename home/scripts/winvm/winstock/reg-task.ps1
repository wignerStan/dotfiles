$ErrorActionPreference = 'Stop'
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c C:\Users\jacob\winstock-watch.bat'
$principal = New-ScheduledTaskPrincipal -UserId 'jacob' -LogonType Interactive -RunLevel Highest
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
Register-ScheduledTask -TaskName 'winstock-test' -Action $action -Principal $principal -Trigger $trigger -Force | Out-Null
Start-ScheduledTask -TaskName 'winstock-test'
Write-Host "task registered + started"
