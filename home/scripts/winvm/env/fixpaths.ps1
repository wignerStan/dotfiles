$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\fixpaths-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "fixpaths"
foreach ($p in @('C:\Users\Default\AppData\Local\7-Zip','C:\Users\Default\AppData\Local\GeekUninstaller','C:\Users\Default\AppData\Roaming\uv','C:\Users\Default\.local')) {
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -EA SilentlyContinue; W ("removed {0}: {1}" -f $p, (-not (Test-Path $p))) }
}
# strip Default entries from jacob's User PATH
$up = [Environment]::GetEnvironmentVariable('Path','User', [EnvironmentVariableTarget]::User)
$new = (($up -split ';') | Where-Object { $_ -and $_ -notmatch 'Default' }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $new, [EnvironmentVariableTarget]::User)
W "PATH cleaned"
W "DONE"