$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$d = "\\Mac\Home\Downloads\vm-backup"
New-Item -ItemType Directory -Force -Path "$d\reg","$d\$U" | Out-Null

# Registry
reg export "HKCU\SOFTWARE" "$d\reg\HKCU-SOFTWARE.reg" /y 2>$null
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "$d\reg\Uninstall.reg" /y 2>$null
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "$d\reg\Run-HKLM.reg" /y 2>$null
reg export "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "$d\reg\Run-HKCU.reg" /y 2>$null
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "$d\reg\Winlogon.reg" /y 2>$null

# Key files
Copy-Item "$H\.ssh" "$d\$U\ssh" -Recurse -Force -EA SilentlyContinue
Copy-Item "$H\.config\chezmoi" "$d\$U\chezmoi" -Recurse -Force -EA SilentlyContinue
Copy-Item "$H\Desktop" "$d\$U\Desktop" -Recurse -Force -EA SilentlyContinue
Copy-Item "$H\Documents" "$d\$U\Documents" -Recurse -Force -EA SilentlyContinue

# 金字塔 config
New-Item -ItemType Directory -Force -Path "$d\jzt" | Out-Null
Get-ChildItem "C:\Weisoft Stock(x64)" -EA SilentlyContinue | Where-Object { $_.Extension -in ".xml",".ini",".dat" } | Copy-Item -Destination "$d\jzt\" -Force

# Software inventory
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA SilentlyContinue | Where-Object { $_.DisplayName } | Select DisplayName,DisplayVersion | Sort DisplayName | Out-File "$d\software.txt" -Encoding UTF8

"DONE" | Out-File "$d\done.flag"