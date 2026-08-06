$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$ErrorActionPreference = 'Continue'
$log = "$H\restore-user-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "user data restore"
$src = '\\Mac\Home\restore-src\jacob'
# copy backup jacob dir to a share-accessible staging: use \\Mac\Home direct
$share = '\\Mac\Home'
# 1. ssh files
New-Item -ItemType Directory -Force -Path "$H\.ssh" | Out-Null
foreach ($f in @('config','known_hosts','known_hosts.old','id_chezmoi.pub')) {
    $s = "$share\ssh-backup\$f"
    if (Test-Path $s) {
        if ($f -eq 'config' -and (Test-Path "$H\.ssh\config")) {
            Copy-Item $s "$H\.ssh\config.vm-backup" -Force
            W "ssh config: saved backup copy as config.vm-backup (chezmoi-managed config kept)"
        } else {
            Copy-Item $s "$H\.ssh\$f" -Force
            W "restored .ssh\$f"
        }
    } else { W "skip $f (not in backup)" }
}
# 2. chezmoi reference files (archive, don't overwrite active)
foreach ($f in @('chezmoi.toml','chezmoistate.boltdb')) {
    $s = "$share\chezmoi-backup\$f"
    if (Test-Path $s) {
        Copy-Item $s "$H\.config\chezmoi\$f.vm-backup" -Force
        W "archived $f -> .config\chezmoi\$f.vm-backup"
    }
}
W "DONE"