@echo off
rem run-as-jacob.bat - "sudo -u <desk user>" equivalent from the SYSTEM prlctl enter
rem session. ASCII only (guest codepage is GBK; any UTF-8 in comments breaks cmd).
rem
rem The guest desk account has a BLANK password (autologon), so Parallels
rem prlctl exec --user <user> cannot authenticate with an empty password. Headless
rem deploy must use the SYSTEM prlctl enter session and drop to the desk user via
rem an interactive scheduled task (/IT uses the logged-on console token, no pw).
rem Run as the desk user for normal operations; drop to raw SYSTEM only for
rem elevated ones (see run-elevated.bat).
rem
rem Usage:  call run-as-jacob.bat "command-line"
setlocal
set "CMD=%~1"
set "TN=runasj%RANDOM%"
rem Resolve the desk user (autologon DefaultUserName) even in a SYSTEM session.
set "U="
for /f "tokens=3" %%U in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName 2^>nul ^| find "DefaultUserName"') do set "U=%%U"
if not defined U set "U=%USERNAME%"
schtasks /Create /TN "%TN%" /TR "%CMD%" /SC ONCE /ST 23:58 /RU %U% /IT /F >nul 2>&1
schtasks /Run /TN "%TN%" >nul 2>&1
:wait
schtasks /Query /TN "%TN%" /V /FO LIST 2>nul | findstr /R /C:"״̬" | findstr /i "Running" >nul && (timeout /t 1 /nobreak >nul & goto :wait)
schtasks /Delete /TN "%TN%" /F >nul 2>&1
endlocal