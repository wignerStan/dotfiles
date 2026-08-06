# Jacob's Windows chezmoi bootstrap (Phase 2) — run as jacob
# Note: binaries are downloaded from their release URLs (no shared-folder
# installers). See run_onchange_windows-setup.ps1.tmpl for the full setup.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$share = '\\Mac\Home'
$H = 'C:\Users\jacob'
$env:HOME = $H
$env:USERPROFILE = $H

function Get-LatestRelease {
    param([string]$Repo)
    try {
        $r = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'chezmoi-bootstrap' }
        return $r.tag_name
    } catch { return $null }
}

Write-Host "==> [1/6] staging MinGit"
if (-not (Test-Path "$H\.local\mingit\cmd\git.exe")) {
    $gTag = Get-LatestRelease 'git-for-windows/git'
    $gv = ($gTag -replace '^v','' -replace '\.windows\.','.')
    $gUrl = "https://github.com/git-for-windows/git/releases/download/$gTag/MinGit-$gv-arm64.zip"
    if ($gTag) {
        $zip = "$H\Downloads\MinGit-$gv-arm64.zip"
        Invoke-WebRequest -Uri $gUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath "$H\.local\mingit" -Force
        Remove-Item $zip -Force -EA SilentlyContinue
        Write-Host "    MinGit $gv staged from $gUrl"
    } else {
        Write-Host "    WARN: GitHub unreachable, MinGit not staged"
    }
} else { Write-Host "    MinGit already present" }

Write-Host "==> [2/6] staging chezmoi"
if (-not (Test-Path "$H\.local\chezmoi\chezmoi.exe")) {
    $cTag = Get-LatestRelease 'twpayne/chezmoi'
    $cUrl = "https://github.com/twpayne/chezmoi/releases/download/$cTag/chezmoi_$($cTag.TrimStart('v'))_windows_arm64.zip"
    if ($cTag) {
        $zip = "$H\Downloads\chezmoi_$($cTag.TrimStart('v'))_windows_arm64.zip"
        Invoke-WebRequest -Uri $cUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath "$H\.local\chezmoi" -Force
        Remove-Item $zip -Force -EA SilentlyContinue
        Write-Host "    chezmoi $cTag staged from $cUrl"
    } else {
        Write-Host "    WARN: GitHub unreachable, chezmoi not staged"
    }
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
