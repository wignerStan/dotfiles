$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\installpy-log.txt"
"=== install python (direct conda-forge) $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$env:MAMBA_ROOT_PREFIX = "$H\mamba"
$root = "$H\mamba"

# clear stalled repodata cache
"clearing pkgs cache (stalled)..." | Add-Content -Path $log -Encoding UTF8
Remove-Item "$root\pkgs" -Recurse -Force -EA SilentlyContinue
Remove-Item "$root\pkgs\cache" -Recurse -Force -EA SilentlyContinue

# install from DIRECT conda-forge (override .condarc USTC mirror), with timeout + progress
"installing python=3.13 from direct conda-forge..." | Add-Content -Path $log -Encoding UTF8
$job = Start-Job -ScriptBlock {
    $env:MAMBA_ROOT_PREFIX = "$H\mamba"
    & micromamba install -y -c https://conda.anaconda.org/conda-forge --override-channels python=3.13 -r "$H\mamba" 2>&1
}
# wait up to 6 minutes
if (Wait-Job $job -Timeout 360) {
    (Receive-Job $job | Out-String) | Add-Content -Path $log -Encoding UTF8
} else {
    "TIMEOUT after 6 min — killing" | Add-Content -Path $log -Encoding UTF8
    Stop-Job $job; Receive-Job $job | Out-String | Add-Content -Path $log -Encoding UTF8
    # force-kill micromamba
    Get-Process micromamba -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
}
Remove-Job $job -Force

"python.exe: $(Test-Path "$root\python.exe")" | Add-Content -Path $log -Encoding UTF8
if (Test-Path "$root\python.exe") {
    "version: $((& "$root\python.exe" --version 2>&1))" | Add-Content -Path $log -Encoding UTF8
    "pkgs dirs: $((Get-ChildItem "$root\pkgs" -Directory -EA SilentlyContinue).Count)" | Add-Content -Path $log -Encoding UTF8
}
"DONE" | Add-Content -Path $log -Encoding UTF8