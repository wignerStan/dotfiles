$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$ErrorActionPreference = 'Stop'
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c $H\winstock-watch.bat"
$principal = New-ScheduledTaskPrincipal -UserId $U -LogonType Interactive -RunLevel Highest
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
Register-ScheduledTask -TaskName 'winstock-test' -Action $action -Principal $principal -Trigger $trigger -Force | Out-Null
Start-ScheduledTask -TaskName 'winstock-test'
Write-Host "task registered + started"