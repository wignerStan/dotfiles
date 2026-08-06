$ErrorActionPreference = 'Continue'
$log = 'C:\Users\jacob\fixpath2-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "path fix"
$dirs = @('C:\Users\jacob\.local\mingit\cmd','C:\Users\jacob\.local\mingit\mingw64\bin','C:\Users\jacob\.local\uv','C:\Users\jacob\AppData\Local\7-Zip','C:\Users\jacob\AppData\Local\GeekUninstaller')

# 1. Machine PATH (works for ALL sessions incl exec)
$mp = [Environment]::GetEnvironmentVariable('Path','Machine')
$parts = @($mp -split ';' | Where-Object { $_ })
foreach ($d in $dirs) { if ($parts -notcontains $d) { $parts += $d } }
[Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'Machine')
W "Machine PATH updated ($(($parts | Measure-Object).Count) entries)"

# 2. jacob HKCU Environment\Path via hive mount
reg load "HKU\JACOB" 'C:\Users\jacob\NTUSER.DAT' 2>&1 | Out-Null
$up = (reg query "HKU\JACOB\Environment" /v Path 2>$null | Select-String 'REG_EXPAND_SZ|REG_SZ' | Out-String)
$cur = ''
if ($up -match 'Path\s+REG_EXPAND_SZ\s+(.+)') { $cur = $Matches[1].Trim() }
elseif ($up -match 'Path\s+REG_SZ\s+(.+)') { $cur = $Matches[1].Trim() }
W "existing HKCU Path: [$cur]"
$newPath = $cur
$uparts = @($newPath -split ';' | Where-Object { $_ })
foreach ($d in $dirs) { if ($uparts -notcontains $d) { $uparts += $d } }
$joined = ($uparts -join ';')
# set as REG_EXPAND_SZ (original may have had %vars%)
reg add "HKU\JACOB\Environment" /v Path /t REG_EXPAND_SZ /d $joined /f 2>&1 | Out-String | % { W ($_.Trim()) }
reg unload "HKU\JACOB" 2>&1 | Out-Null
W "HKCU Path updated: $joined"
W "DONE"
