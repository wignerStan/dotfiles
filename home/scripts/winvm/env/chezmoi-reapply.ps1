$log = "C:\Users\jacob\Downloads\reapply-fix-log.txt"
"=== reapply (mamba base fix) $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$env:MAMBA_ROOT_PREFIX = "C:\Users\jacob\mamba"
$src = "$env:USERPROFILE\.local\share\chezmoi"
$cfg = "$env:USERPROFILE\.config\chezmoi\chezmoi.toml"

# pull the fixed bootstrap from repo
"pulling latest..." | Add-Content -Path $log -Encoding UTF8
Push-Location $src
& git pull --quiet origin main 2>&1 | Add-Content -Path $log -Encoding UTF8
Pop-Location

# clear the broken empty base dir so install starts clean
$mambaRoot = "C:\Users\jacob\mamba"
if (Test-Path "$mambaRoot\python.exe") { "python already present, skipping" | Add-Content -Path $log -Encoding UTF8 }
else { "base empty — bootstrap will install python" | Add-Content -Path $log -Encoding UTF8 }

# re-stage secrets (git pull may not include them; they're gitignored)
$cd = "$src\home\.chezmoidata"
New-Item -ItemType Directory -Force -Path $cd | Out-Null
Copy-Item "\\Mac\Home\.local\share\chezmoi\home\.chezmoidata\secrets.toml" "$cd\secrets.toml" -Force -EA SilentlyContinue

# apply (triggers the fixed bootstrap)
"applying chezmoi..." | Add-Content -Path $log -Encoding UTF8
& chezmoi apply --source "$src" --config "$cfg" --no-tty 2>&1 | Tee-Object -FilePath $log -Append | Out-Null
"apply exit: $LASTEXITCODE" | Add-Content -Path $log -Encoding UTF8
"DONE" | Add-Content -Path $log -Encoding UTF8
