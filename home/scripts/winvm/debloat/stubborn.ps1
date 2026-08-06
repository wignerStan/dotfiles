$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$ErrorActionPreference = 'Continue'
$log = "$H\stubborn-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "STUBBORN cleanup start as $env:USERNAME"

# ── 1. Edge: enable uninstall + run uninstaller if present ──
W "== Edge uninstall entries =="
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /v UninstallString 2>&1 | Out-String | % { W ($_.Trim()) }
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /v UninstallString 2>&1 | Out-String | % { W ($_.Trim()) }

# enable uninstall via EdgeUpdateDev
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev" /v AllowUninstall /t REG_SZ /d "" /f 2>&1 | Out-String | % { W ($_.Trim()) }

$un = $null
$u1 = (reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /v UninstallString 2>$null | Select-String 'REG_SZ' | Out-String).Trim()
if ($u1 -match 'REG_SZ\s+(.+)') { $un = $Matches[1] }
if ($un) {
    W "UninstallString: $un"
    $cmd = "$un --force-uninstall"
    W "running: $cmd"
    cmd /c $cmd 2>&1 | Out-String | % { W ($_.Trim()) }
    Start-Sleep -Seconds 10
} else { W "no uninstaller found - manual removal" }

# ── 2. Edge leftover dirs: takeown + delete ──
$dirs = @(
    'C:\Program Files (x86)\Microsoft\Edge',
    'C:\Program Files (x86)\Microsoft\EdgeCore',
    'C:\Program Files (x86)\Microsoft\EdgeWebView',
    'C:\Program Files (x86)\Microsoft\EdgeUpdate',
    'C:\Program Files\Microsoft\EdgeWebView',
    'C:\Program Files\Microsoft\EdgeCore',
    'C:\Program Files\Microsoft\EdgeUpdate',
    'C:\ProgramData\Microsoft\EdgeUpdate'
)
foreach ($d in $dirs) {
    if (Test-Path $d) {
        W "deleting $d ..."
        takeown.exe /f $d /r /d Y 2>&1 | Out-Null
        icacls.exe $d /grant "*S-1-5-18:(OI)(CI)F" "Administrators:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
        Remove-Item -LiteralPath $d -Recurse -Force -EA SilentlyContinue
        W ("  gone: {0}" -f (-not (Test-Path $d)))
    }
}

# shortcuts
$lnks = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
    "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
    "$env:USERPROFILE\Desktop\Microsoft Edge.lnk"
)
foreach ($l in $lnks) { if (Test-Path $l) { Remove-Item $l -Force -EA SilentlyContinue; W "removed lnk $l" } }

# ── 3. SecHealthUI (Windows Security UI) ──
W "== SecHealthUI =="
$secDirs = Get-ChildItem 'C:\Windows\SystemApps' -Directory -Filter 'Microsoft.SecHealthUI*' -EA SilentlyContinue
if ($secDirs) {
    foreach ($d in $secDirs) {
        W "removing $($d.FullName)"
        takeown.exe /f $d.FullName /r /d Y 2>&1 | Out-Null
        icacls.exe $d.FullName /grant "*S-1-5-18:(OI)(CI)F" "Administrators:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
        Remove-Item -LiteralPath $d.FullName -Recurse -Force -EA SilentlyContinue
        W ("  gone: {0}" -f (-not (Test-Path $d.FullName)))
    }
} else { W "SecHealthUI dirs: none" }
# registry registration
$store = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
reg query $store /s /f "SecHealthUI" /k 2>&1 | Select-String 'SecHealthUI' | ForEach-Object {
    $k = ($_.Line -split ' ')[-1]
    reg delete $k /f 2>&1 | Out-Null
    W "reg deleted $k"
}
# SecurityHealth service off
sc.exe config SecurityHealthService start= disabled 2>&1 | Out-String | % { W ($_.Trim()) }
sc.exe stop SecurityHealthService 2>&1 | Out-String | % { W ($_.Trim()) }
# tray icon
if (Test-Path 'C:\Windows\System32\SecurityHealthSystray.exe') { sc.exe config SecurityHealthSystray start= disabled 2>&1 | Out-String | % { W ($_.Trim()) } }

# ── 4. leftovers sweep ──
W "== leftover checks =="
W ("msedge.exe: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'))
W ("EdgeWebView: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView'))
W ("EdgeCore: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeCore'))
W "DONE"