$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\rm-stubs-log.txt"
"=== remove DesktopAppInstaller stub packages $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# Remove the neutral stub packages (language resource + bundle manifest) that survived.
# The main arm64 package is already gone; these keep the registration alive.
$pkgs = Get-AppxPackage -AllUsers -Name "Microsoft.DesktopAppInstaller" -EA SilentlyContinue
W "found $($pkgs.Count) DesktopAppInstaller package(s):"
foreach ($p in $pkgs) { W "  $($p.PackageFullName)" }
foreach ($p in $pkgs) {
    try {
        $p | Remove-AppxPackage -AllUsers -EA Stop
        W "removed: $($p.PackageFullName)"
    } catch { W "Appx fail $($p.PackageFullName): $($_.Exception.Message)" }
}

# Delete any leftover WindowsApps folders via SYSTEM takeown
foreach ($d in (Get-ChildItem "C:\Program Files\WindowsApps" -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "DesktopAppInstaller" })) {
    & takeown.exe /f $d.FullName /r /d Y 2>&1 | Out-Null
    & icacls.exe $d.FullName /grant "*S-1-5-18:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
    Remove-Item $d.FullName -Recurse -Force -EA SilentlyContinue
    W "folder $($d.Name): gone=$(-not (Test-Path $d.FullName))"
}

# also clean staged/config reg entries so AppXSvc won't resurrect them
foreach ($root in @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Staged",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Config",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\ConfigS-1-5-18"
)) {
    Get-ChildItem $root -EA SilentlyContinue | Where-Object { $_.PSChildName -match "DesktopAppInstaller" } | ForEach-Object {
        Remove-Item -LiteralPath $_.PSPath -Recurse -Force -EA SilentlyContinue
        W "reg removed: $($_.PSChildName)"
    }
}

W "`n=== verify ==="
$still = Get-AppxPackage -AllUsers -Name "Microsoft.DesktopAppInstaller" -EA SilentlyContinue
W "DesktopAppInstaller present: $([bool]$still)"
W "winget cmd: $([bool](Get-Command winget -EA SilentlyContinue))"
$dirs = Get-ChildItem "C:\Program Files\WindowsApps" -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "DesktopAppInstaller" }
W "WindowsApps DAI folders: $($dirs.Count)"
W "DONE"