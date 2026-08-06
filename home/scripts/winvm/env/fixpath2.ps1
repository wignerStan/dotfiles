$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$ErrorActionPreference = 'Continue'
$log = "$H\fixpath2-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "path fix"
$dirs = @("$H\.local\mingit\cmd","$H\.local\mingit\mingw64\bin","$H\.local\uv","$H\AppData\Local\7-Zip","$H\AppData\Local\GeekUninstaller")

# 1. Machine PATH (works for ALL sessions incl exec)
$mp = [Environment]::GetEnvironmentVariable('Path','Machine')
$parts = @($mp -split ';' | Where-Object { $_ })
foreach ($d in $dirs) { if ($parts -notcontains $d) { $parts += $d } }
[Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'Machine')
W "Machine PATH updated ($(($parts | Measure-Object).Count) entries)"

# 2. jacob HKCU Environment\Path via hive mount
reg load "HKU\$U" "$H\NTUSER.DAT" 2>&1 | Out-Null
$up = (reg query "HKU\$U\Environment" /v Path 2>$null | Select-String 'REG_EXPAND_SZ|REG_SZ' | Out-String)
$cur = ''
if ($up -match 'Path\s+REG_EXPAND_SZ\s+(.+)') { $cur = $Matches[1].Trim() }
elseif ($up -match 'Path\s+REG_SZ\s+(.+)') { $cur = $Matches[1].Trim() }
W "existing HKCU Path: [$cur]"
$newPath = $cur
$uparts = @($newPath -split ';' | Where-Object { $_ })
foreach ($d in $dirs) { if ($uparts -notcontains $d) { $uparts += $d } }
$joined = ($uparts -join ';')
# set as REG_EXPAND_SZ (original may have had %vars%)
reg add "HKU\$U\Environment" /v Path /t REG_EXPAND_SZ /d $joined /f 2>&1 | Out-String | % { W ($_.Trim()) }
reg unload "HKU\$U" 2>&1 | Out-Null
W "HKCU Path updated: $joined"
W "DONE"