@echo off
rem fix-autologin.bat - set up blank-password autologon for the guest user.
rem ASCII only (guest codepage is GBK).
rem
rem State: jacob has a BLANK password (net user jacob ""). Autologon then needs
rem AutoAdminLogon=1 + DefaultUserName=jacob and NO DefaultPassword (a stale
rem DefaultPassword that does not match causes Windows to fall back to the
rem LogonUI login screen - see docs win11-vm-troubleshooting.md "autologon").
rem consequence: prlctl exec --user <user> cannot authenticate (needs a password),
rem so headless work uses the SYSTEM prlctl enter session + run-as-jacob.bat
rem / run-elevated.bat (interactive scheduled tasks drop to the user as "sudo -u").
rem Resolve the desk user (autologon DefaultUserName) even in a SYSTEM session.
set "U="
for /f "tokens=3" %%U in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName 2>nul ^| find "DefaultUserName"') do set "U=%%U"
if not defined U set "U=%USERNAME%"
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f >/dev/null 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d %U% /f >/dev/null 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f >/dev/null 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonCount /f >/dev/null 2>&1
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
echo DONE > %USERPROFILE%\fixal.txt
