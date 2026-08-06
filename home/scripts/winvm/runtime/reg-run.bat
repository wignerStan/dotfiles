@echo off
cd /d "C:\Weisoft Stock(x64)"
call register.bat > %USERPROFILE%\register-out.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> %USERPROFILE%\register-out.txt
