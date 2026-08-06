$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\force-rm-store-log.txt"
"=== FORCE remove Store + winget system packages $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$before = (Get-PSDrive C).Free
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# Targets: Microsoft Store, Store Purchase App, AppInstaller (winget)
$targets = @('Microsoft.WindowsStore','Microsoft.StorePurchaseApp','Microsoft.DesktopAppInstaller')

# ── METHOD 1: registry-staged-key removal trick ──
# On 24H2, Remove-AppxPackage fails (0x80070032) because the package is staged as a
# system component in AppxAllUserStore\Staged. Deleting the staged+installed registry
# entries first lets Remove-AppxPackage succeed (or the package just disappears).
$stagedRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Staged"
$installedRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Config"
foreach ($t in $targets) {
    W "`n[$t] registry-staged removal"
    $pkg = Get-AppxPackage -AllUsers -Name $t -EA SilentlyContinue
    if (-not $pkg) { W "  not installed (already gone?)"; continue }
    $fn = $pkg.PackageFullName
    W "  fullname: $fn"
    # take ownership of the registry keys so we can delete them
    foreach ($root in @($stagedRoot,$installedRoot)) {
        $key = Join-Path $root $fn
        if (Test-Path $key) {
            try {
                & reg.exe add "$($key -replace 'HKLM:\\','HKLM\')" /v Owned /t REG_DWORD /d 1 /f 2>&1 | Out-Null
                # use PowerShell to delete (needs admin, which we have)
                Remove-Item -LiteralPath $key -Recurse -Force -EA Stop
                W "  removed reg key: $key"
            } catch {
                # force via reg.exe after taking ownership
                & reg.exe ownership "$($key -replace 'HKLM:\\','HKLM\')" 2>&1 | Out-Null
                & reg.exe delete "$($key -replace 'HKLM:\\','HKLM\')" /f 2>&1 | Out-Null
                W "  reg delete (via reg.exe): attempted $key"
            }
        }
    }
    # now try Remove-AppxPackage again
    try {
        Remove-AppxPackage -Package $fn -AllUsers -EA Stop
        W "  Remove-AppxPackage: OK (gone=$(-not (Get-AppxPackage -AllUsers -Name $t -EA SilentlyContinue)))"
    } catch {
        W "  Remove-AppxPackage still failed: $($_.Exception.Message.Split("`n")[0])"
    }
}

# ── METHOD 2 (fallback): takeown + delete the WindowsApps folders ──
W "`n=== takeown+delete fallback ==="
foreach ($t in $targets) {
    $pkg = Get-AppxPackage -AllUsers -Name $t -EA SilentlyContinue
    $loc = if ($pkg) { $pkg.InstallLocation } else {
        Get-ChildItem "C:\Program Files\WindowsApps" -Directory -Filter "$t*" -EA SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $loc -or -not (Test-Path $loc)) { W "[$t] no folder found"; continue }
    $sz = [math]::Round((Get-ChildItem $loc -Recurse -Force -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1MB,1)
    W "[$t] taking ownership of $loc ($sz MB)"
    & takeown.exe /f $loc /r /d Y 2>&1 | Out-Null
    & icacls.exe $loc /grant "Administrators:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
    Remove-Item -LiteralPath $loc -Recurse -Force -EA SilentlyContinue
    W "  gone=$(-not (Test-Path $loc))"
}

# ── disable Store-related services ──
W "`n=== disable Store services ==="
foreach ($svc in @('InstallService','LicenseManager','UnistoreSvc')) {
    try { Stop-Service $svc -Force -EA SilentlyContinue; Set-Service $svc -StartupType Disabled -EA SilentlyContinue; W "  disabled $svc" } catch { W "  ${svc}: $($_.Exception.Message)" }
}

$after = (Get-PSDrive C).Free
W "`n=== RESULT: C: free {0:N1} -> {1:N1} GB (delta {2:N1} GB) ===" -f ($before/1GB),($after/1GB),(($after-$before)/1GB)
W "DONE"