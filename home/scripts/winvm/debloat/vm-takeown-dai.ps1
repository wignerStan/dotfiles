$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\takeown-dai-log.txt"
"=== takeown/icacls DesktopAppInstaller removal $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# 1. Does the arm64 folder exist anywhere now? (re-stage may have recreated it)
W "=== filesystem ==="
$dirs = Get-ChildItem "C:\Program Files\WindowsApps" -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "DesktopAppInstaller" }
W "DAI folders in WindowsApps: $($dirs.Count)"
foreach ($d in $dirs) { W "  $($d.FullName)" }

# 2. Find the Appx registry entries for this package and take ownership + delete
W "`n=== registry (Appx deployment store) ==="
$roots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Staged",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Config",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\User"   # per-user staging
)
# also enumerate any AppxAllUserStore subkey containing DesktopAppInstaller
$storeRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"
$allKeys = Get-ChildItem $storeRoot -Recurse -EA SilentlyContinue | Where-Object { $_.Name -match "DesktopAppInstaller" }
W "Appx registry keys matching DAI: $($allKeys.Count)"
foreach ($k in $allKeys) { W "  $($k.PSPath)" }

# take ownership + delete each (reg key ownership via PowerShell as SYSTEM)
foreach ($k in $allKeys) {
    $path = $k.PSPath
    try {
        $acl = Get-Acl -LiteralPath $path -EA Stop
        # as SYSTEM we may already own; try delete
        Remove-Item -LiteralPath $path -Recurse -Force -EA Stop
        W "removed reg: $($k.PSChildName)"
    } catch {
        # take ownership via .NET, then delete
        try {
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(($path -replace 'HKLM:\\',''), [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
            $regAcl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
            $regAcl.SetOwner((New-Object System.Security.Principal.NTAccount("NT AUTHORITY\SYSTEM")))
            $key.SetAccessControl($regAcl)
            $key.Close()
            $key2 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(($path -replace 'HKLM:\\',''), [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            $regAcl2 = $key2.GetAccessControl()
            $regAcl2.SetAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule("Administrators","FullControl","ContainerInherit","None","Allow")))
            $key2.SetAccessControl($regAcl2)
            $key2.Close()
            Remove-Item -LiteralPath $path -Recurse -Force -EA Stop
            W "removed reg (after takeown): $($k.PSChildName)"
        } catch {
            W "reg FAIL $($k.PSChildName): $($_.Exception.Message)"
        }
    }
}

# 3. takeown + delete any arm64 folder
W "`n=== takeown folders ==="
$armDir = Get-ChildItem "C:\Program Files\WindowsApps" -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "DesktopAppInstaller_1.29.280.0_arm64" } | Select-Object -First 1
if ($armDir) {
    & takeown.exe /f $armDir.FullName /r /d Y 2>&1 | Out-Null
    & icacls.exe $armDir.FullName /grant "*S-1-5-18:(OI)(CI)F" "Administrators:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
    Remove-Item $armDir.FullName -Recurse -Force -EA SilentlyContinue
    W "arm64 folder gone: $(-not (Test-Path $armDir.FullName))"
} else { W "no arm64 folder present" }

W "`n=== final verify ==="
W "DAI present: $([bool](Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -EA SilentlyContinue))"
W "winget cmd: $([bool](Get-Command winget -EA SilentlyContinue))"
W "DAI folders: $((Get-ChildItem 'C:\Program Files\WindowsApps' -Directory -EA SilentlyContinue | Where-Object { $_.Name -match 'DesktopAppInstaller' }).Count)"
W "DONE"