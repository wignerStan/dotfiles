$ErrorActionPreference = "SilentlyContinue"
$src = "\\Mac\Home\Downloads\vm-backup"
$u = $env:USERPROFILE

# SSH
New-Item -ItemType Directory -Force "$u\.ssh" | Out-Null
Copy-Item "$src\jacob\ssh\*" "$u\.ssh\" -Force
$ssh = (Get-ChildItem "$u\.ssh" -EA SilentlyContinue).Count

# Chezmoi
New-Item -ItemType Directory -Force "$u\.config\chezmoi" | Out-Null
Copy-Item "$src\jacob\chezmoi\*" "$u\.config\chezmoi\" -Force
$cz = (Get-ChildItem "$u\.config\chezmoi" -EA SilentlyContinue).Count

# Desktop
Copy-Item "$src\jacob\Desktop\*" "$u\Desktop\" -Recurse -Force -EA SilentlyContinue
$dt = (Get-ChildItem "$u\Desktop" -Recurse -EA SilentlyContinue).Count

# Documents
Copy-Item "$src\jacob\Documents\*" "$u\Documents\" -Recurse -Force -EA SilentlyContinue
$dc = (Get-ChildItem "$u\Documents" -Recurse -EA SilentlyContinue).Count

# Pyramid config
New-Item -ItemType Directory -Force "$u\jzt-backup" | Out-Null
Copy-Item "$src\jzt\*" "$u\jzt-backup\" -Force
$jzt = (Get-ChildItem "$u\jzt-backup" -EA SilentlyContinue).Count

# Registry files
New-Item -ItemType Directory -Force "$u\Downloads\reg-backup" | Out-Null
Copy-Item "$src\reg\*" "$u\Downloads\reg-backup\" -Force
$reg = (Get-ChildItem "$u\Downloads\reg-backup" -EA SilentlyContinue).Count

# Software list
Copy-Item "$src\software.txt" "$u\Downloads\previous-software.txt" -Force

"SSH=$ssh chezmoi=$cz Desktop=$dt Docs=$dc Pyramid=$jzt Reg=$reg"
