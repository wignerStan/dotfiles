@echo off
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f > C:\Users\jacob\uac-out.txt 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f >> C:\Users\jacob\uac-out.txt 2>&1
echo DONE >> C:\Users\jacob\uac-out.txt
