@echo off
%USERPROFILE%\.local\chezmoi\chezmoi.exe apply --force > %USERPROFILE%\apply-log.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> %USERPROFILE%\apply-log.txt
