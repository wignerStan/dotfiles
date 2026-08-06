$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$ErrorActionPreference = 'Continue'
$log = "$H\final-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "final cleanup as $env:USERNAME"

# 1. SecHealthUI registration keys — search store broadly
W "== SecHealthUI reg search =="
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore" /s /f "SecHealthUI" 2>&1 | Select-String 'HKEY_' | ForEach-Object {
    $k = ($_.Line -split '\s+')[-1]
    W "  found: $k"
    reg delete $k /f 2>&1 | Out-Null
    W "    deleted"
}
# also check the Appx "AppxAllUserStore" sibling: Appx "package roots" in StateRepository are reconciled on boot; try Disable-AppxPackage style:
$pkg = Get-AppxPackage -AllUsers -EA SilentlyContinue | Where-Object { $_.Name -eq 'Microsoft.SecHealthUI' }
if ($pkg) {
    W "  SecHealthUI still present: $($pkg.PackageFullName)"
    # Try removing registration via Appx deployment API with deprovision
    try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -EA Stop; W "  remove ok" }
    catch { W "  remove fail: $($_.Exception.Message.Substring(0,[Math]::Min(150,$_.Exception.Message.Length)))" }
}

# 2. EdgeDevToolsClient SystemApps dir — verbose delete
W "== EdgeDevToolsClient =="
$dt = 'C:\Windows\SystemApps\Microsoft.MicrosoftEdgeDevToolsClient_8wekyb3d8bbwe'
if (Test-Path $dt) {
    takeown.exe /f $dt /r /d Y 2>&1 | Select-Object -First 2 | ForEach-Object { W "  takeown: $_" }
    icacls.exe $dt /grant "*S-1-5-18:(OI)(CI)F" /t /c /q 2>&1 | Select-Object -First 2 | ForEach-Object { W "  icacls: $_" }
    try { Remove-Item -LiteralPath $dt -Recurse -Force -ErrorAction Stop; W "  removed OK" }
    catch { W "  remove FAILED: $($_.Exception.Message)" }
}
$pkg = Get-AppxPackage -AllUsers -EA SilentlyContinue | Where-Object { $_.Name -eq 'Microsoft.MicrosoftEdgeDevToolsClient' }
if ($pkg) {
    try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -EA Stop; W "  appx remove ok" }
    catch { W "  appx remove fail: $($_.Exception.Message.Substring(0,[Math]::Min(150,$_.Exception.Message.Length)))" }
}

# 3. EdgeUpdate dirs — who's locking?
W "== EdgeUpdate locks =="
tasklist 2>$null | Select-String 'edge' | ForEach-Object { W "  proc: $_" }
foreach ($d in @('C:\Program Files (x86)\Microsoft\EdgeUpdate','C:\ProgramData\Microsoft\EdgeUpdate')) {
    if (Test-Path $d) {
        Get-ChildItem $d -Recurse -File -EA SilentlyContinue | ForEach-Object {
            try {
                $fs = [System.IO.File]::Open($_.FullName, 'Open', 'ReadWrite', 'None')
                $fs.Close()
            } catch {
                W ("  LOCKED: {0}" -f $_.FullName)
            }
        }
    }
}
# attempt move-to-temp trick then delete
foreach ($d in @('C:\Program Files (x86)\Microsoft\EdgeUpdate','C:\ProgramData\Microsoft\EdgeUpdate')) {
    if (Test-Path $d) {
        $ren = "$d`_old"
        try { Rename-Item $d $ren -Force -EA Stop; W "  renamed $d -> $ren"; Remove-Item $ren -Recurse -Force -EA SilentlyContinue; W "  deleted $ren" }
        catch { W "  rename failed for $d : $($_.Exception.Message)" }
    }
}
W "DONE"