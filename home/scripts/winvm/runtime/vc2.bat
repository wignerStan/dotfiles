@echo off
"\\Mac\Home\vc_redist.arm64.exe" /install /quiet /norestart > C:\Users\jacob\vc2-log.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> C:\Users\jacob\vc2-log.txt
