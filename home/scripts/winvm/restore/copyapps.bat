@echo off
robocopy "X:\Weisoft Stock(x64)" "C:\Weisoft Stock(x64)" /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NP > C:\Users\jacob\copy1-log.txt 2>&1
echo WEISOFT_EXIT=%ERRORLEVEL% >> C:\Users\jacob\copy1-log.txt
robocopy "X:\徽商期货快期V3" "C:\徽商期货快期V3" /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NP >> C:\Users\jacob\copy1-log.txt 2>&1
echo KUAJI_EXIT=%ERRORLEVEL% >> C:\Users\jacob\copy1-log.txt
