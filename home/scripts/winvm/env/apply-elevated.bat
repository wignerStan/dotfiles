@echo off
C:\Users\jacob\.local\chezmoi\chezmoi.exe apply --force > C:\Users\jacob\apply-log.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> C:\Users\jacob\apply-log.txt
