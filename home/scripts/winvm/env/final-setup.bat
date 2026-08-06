@echo off
rem Resolve the desk user (autologon DefaultUserName) even in a SYSTEM session.
set "U="
for /f "tokens=3" %%U in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName 2>nul ^| find "DefaultUserName"') do set "U=%%U"
if not defined U set "U=%USERNAME%"
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f >/dev/null 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d %U% /f >/dev/null 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d P@ssw0rd!VM /f >/dev/null 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonCount /f >/dev/null 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >/dev/null 2>&1
powercfg /change standby-timeout-ac 0 >/dev/null 2>&1
powercfg /change monitor-timeout-ac 0 >/dev/null 2>&1
echo DONE > %USERPROFILE%\final-setup.txt
