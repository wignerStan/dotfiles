$d = "\\Mac\Home\Downloads\vm-backup"
New-Item -ItemType Directory -Force -Path "$d\reg","$d\jacob" | Out-Null

# Registry
reg export "HKCU\SOFTWARE" "$d\reg\HKCU-SOFTWARE.reg" /y 2>$null
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "$d\reg\Uninstall.reg" /y 2>$null
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "$d\reg\Run-HKLM.reg" /y 2>$null
reg export "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "$d\reg\Run-HKCU.reg" /y 2>$null
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "$d\reg\Winlogon.reg" /y 2>$null

# Key files
Copy-Item "C:\Users\jacob\.ssh" "$d\jacob\ssh" -Recurse -Force -EA SilentlyContinue
Copy-Item "C:\Users\jacob\.config\chezmoi" "$d\jacob\chezmoi" -Recurse -Force -EA SilentlyContinue
Copy-Item "C:\Users\jacob\Desktop" "$d\jacob\Desktop" -Recurse -Force -EA SilentlyContinue
Copy-Item "C:\Users\jacob\Documents" "$d\jacob\Documents" -Recurse -Force -EA SilentlyContinue

# 金字塔 config
New-Item -ItemType Directory -Force -Path "$d\jzt" | Out-Null
Get-ChildItem "C:\Weisoft Stock(x64)" -EA SilentlyContinue | Where-Object { $_.Extension -in ".xml",".ini",".dat" } | Copy-Item -Destination "$d\jzt\" -Force

# Software inventory
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA SilentlyContinue | Where-Object { $_.DisplayName } | Select DisplayName,DisplayVersion | Sort DisplayName | Out-File "$d\software.txt" -Encoding UTF8

"DONE" | Out-File "$d\done.flag"
