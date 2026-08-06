@echo off
echo STEP1 bat start > C:\Users\jacob\winstock-test.log
start "" /D "C:\Weisoft Stock(x64)" "C:\Weisoft Stock(x64)\WinStock.exe"
echo STEP2 start issued >> C:\Users\jacob\winstock-test.log
timeout /t 25 /nobreak >/dev/null
echo STEP3 timeout done >> C:\Users\jacob\winstock-test.log
tasklist | findstr /i WinStock >> C:\Users\jacob\winstock-test.log
"C:\Users\jacob\AppData\Roaming\uv\python\cpython-3.14-windows-aarch64-none\python.exe" C:\Users\jacob\pytest-pywinauto.py >> C:\Users\jacob\winstock-test.log 2>&1
echo STEP4 python exit %ERRORLEVEL% >> C:\Users\jacob\winstock-test.log
