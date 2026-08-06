@echo off
rem run-elevated.bat - run a command escalated as the desk user (admin). Same mechanism
rem as run-as-jacob.bat but /RL HIGHEST gives a UAC-elevated token
rem (ConsentPromptBehaviorAdmin=0 means silent, no prompt). Use when admin rights
rem are needed but the op should still run as the desk user (not SYSTEM). For ops
rem needing TRUE SYSTEM privileges (TrustedInstaller-won files, service changes)
rem use the raw SYSTEM prlctl enter session instead.
rem ASCII only (guest codepage is GBK).
rem Usage:  call run-elevated.bat "command-line"
setlocal
set "CMD=%~1"
set "TN=elevj%RANDOM%"
rem Resolve the desk user (autologon DefaultUserName) even in a SYSTEM session.
set "U="
for /f "tokens=3" %%U in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName 2^>nul ^| find "DefaultUserName"') do set "U=%%U"
if not defined U set "U=%USERNAME%"
schtasks /Create /TN "%TN%" /TR "%CMD%" /SC ONCE /ST 23:58 /RU %U% /RL HIGHEST /IT /F >nul 2>&1
schtasks /Run /TN "%TN%" >nul 2>&1
:wait
schtasks /Query /TN "%TN%" /V /FO LIST 2>nul | findstr /R /C:"״̬" | findstr /i "Running" >nul && (timeout /t 1 /nobreak >nul & goto :wait)
schtasks /Delete /TN "%TN%" /F >nul 2>&1
endlocal