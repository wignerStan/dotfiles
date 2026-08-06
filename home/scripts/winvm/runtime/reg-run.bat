@echo off
cd /d "C:\Weisoft Stock(x64)"
call register.bat > C:\Users\jacob\register-out.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> C:\Users\jacob\register-out.txt
