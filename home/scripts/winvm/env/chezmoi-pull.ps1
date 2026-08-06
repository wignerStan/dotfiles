$log = "C:\Users\jacob\Downloads\pull-log.txt"
"=== fix git ssh + pull $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
$src = "$env:USERPROFILE\.local\share\chezmoi"
Push-Location $src
# point this repo's git at the deploy key (id_chezmoi), overriding any stale sshCommand
git config core.sshCommand "ssh -i C:/Users/jacob/.ssh/id_chezmoi -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
"sshCommand set" | Add-Content -Path $log -Encoding UTF8
"pulling..." | Add-Content -Path $log -Encoding UTF8
$pull = git pull origin main 2>&1 | Out-String
$pull | Add-Content -Path $log -Encoding UTF8
Add-Content -Path $log -Value "pull exit: $LASTEXITCODE" -Encoding UTF8
# verify fix landed
$bs = "$src\home\run_onchange_windows-bootstrap.ps1.tmpl"
"has install -r <root> (fixed): $(Select-String -Path $bs -Pattern 'python -r' -Quiet)" | Add-Content -Path $log -Encoding UTF8
"has create -n base (old): $(Select-String -Path $bs -Pattern 'create -y -n base' -Quiet)" | Add-Content -Path $log -Encoding UTF8
Pop-Location
"DONE" | Add-Content -Path $log -Encoding UTF8
