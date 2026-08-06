# Jacob's Windows chezmoi bootstrap (Phase 2) — run as jacob
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$share = '\\Mac\Home'
$H = 'C:\Users\jacob'
$env:HOME = $H
$env:USERPROFILE = $H

Write-Host "==> [1/6] staging MinGit"
if (-not (Test-Path "$H\.local\mingit\cmd\git.exe")) {
    Expand-Archive -Path "$share\MinGit-arm64.zip" -DestinationPath "$H\.local\mingit" -Force
} else { Write-Host "    MinGit already present" }

Write-Host "==> [2/6] staging chezmoi"
if (-not (Test-Path "$H\.local\chezmoi\chezmoi.exe")) {
    Expand-Archive -Path "$share\chezmoi_win_arm64.zip" -DestinationPath "$H\.local\chezmoi" -Force
} else { Write-Host "    chezmoi already present" }

Write-Host "==> [3/6] staging age key"
New-Item -ItemType Directory -Force -Path "$H\.config\chezmoi\age" | Out-Null
New-Item -ItemType Directory -Force -Path "$H\.local\share\chezmoi\age" | Out-Null
Copy-Item "$share\age-key.txt" "$H\.config\chezmoi\age\keys.txt" -Force
Copy-Item "$share\age-key.txt" "$H\.local\share\chezmoi\age\keys.txt" -Force
Write-Host "    age key copied"

Write-Host "==> [4/6] PATH update"
$up = [Environment]::GetEnvironmentVariable('Path','User')
foreach ($dir in @("$H\.local\mingit\cmd", "$H\.local\chezmoi")) {
    if ($up -notlike "*$dir*") { $up = "$dir;$up" }
}
[Environment]::SetEnvironmentVariable('Path', $up, 'User')
$env:Path = $up
Write-Host "    PATH set"

Write-Host "==> [5/6] chezmoi init"
git config --global user.name "jacob"
git config --global user.email "jacob@winvm.local"
& "$H\.local\chezmoi\chezmoi.exe" init wignerStan/dotfiles 2>&1 | ForEach-Object { Write-Host "    $_" }

Write-Host "==> [6/6] chezmoi apply"
& "$H\.local\chezmoi\chezmoi.exe" apply --force 2>&1 | ForEach-Object { Write-Host "    $_" }

Write-Host "==> DONE"
