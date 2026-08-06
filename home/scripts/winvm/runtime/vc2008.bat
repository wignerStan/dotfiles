@echo off
"C:\Weisoft Stock(x64)\vcredist_x86.exe" /q > %USERPROFILE%\vc2008-log.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> %USERPROFILE%\vc2008-log.txt
