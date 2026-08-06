@echo off
echo STEP1 bat start > %USERPROFILE%\winstock-test.log
start "" /D "C:\Weisoft Stock(x64)" "C:\Weisoft Stock(x64)\WinStock.exe"
echo STEP2 start issued >> %USERPROFILE%\winstock-test.log
timeout /t 25 /nobreak >/dev/null
echo STEP3 timeout done >> %USERPROFILE%\winstock-test.log
tasklist | findstr /i WinStock >> %USERPROFILE%\winstock-test.log
"%USERPROFILE%\AppData\Roaming\uv\python\cpython-3.14-windows-aarch64-none\python.exe" %USERPROFILE%\pytest-pywinauto.py >> %USERPROFILE%\winstock-test.log 2>&1
echo STEP4 python exit %ERRORLEVEL% >> %USERPROFILE%\winstock-test.log
