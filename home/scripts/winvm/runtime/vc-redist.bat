@echo off
rem VC++ redistributable (arm64) — download URL embedded, no shared-folder exe.
setlocal
set DST=%TEMP%\vc_redist.arm64.exe
if not exist "%DST%" curl -L -o "%DST%" "https://aka.ms/vs/17/release/vc_redist.arm64.exe" >nul 2>&1
"%DST%" /install /quiet /norestart > %USERPROFILE%\vcredist-log.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> %USERPROFILE%\vcredist-log.txt
