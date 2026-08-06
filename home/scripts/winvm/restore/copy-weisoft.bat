@echo off
robocopy "X:\Weisoft Stock(x64)" "C:\Weisoft Stock(x64)" /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NP > C:\Users\jacob\robocopy-log.txt 2>&1
echo EXITCODE=%ERRORLEVEL% >> C:\Users\jacob\robocopy-log.txt
