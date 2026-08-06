$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\rm-dai-reg-log.txt"
"=== remove DAI Appx registry (fixed ownership) $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# Enable SeTakeOwnershipPrivilege properly via .NET, then take+delete the Appx store keys.
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using Microsoft.Win32;

public static class RegTake {
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool OpenProcessToken(IntPtr h, int a, out IntPtr t);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool LookupPrivilegeValue(string s, string n, ref LUID l);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool AdjustTokenPrivileges(IntPtr t, bool d, ref TOKEN_PRIVILEGES np, int len, IntPtr prev, IntPtr rel);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [StructLayout(LayoutKind.Sequential)] struct LUID { public uint Low; public int High; }
    [StructLayout(LayoutKind.Sequential)] struct LUID_AND_ATTR { public LUID Luid; public uint Attr; }
    [StructLayout(LayoutKind.Sequential)] struct TOKEN_PRIVILEGES { public uint Count; public LUID_AND_ATTR Priv; }
    const int SE_PRIV_ENABLED = 2;

    static void Enable(string name) {
        OpenProcessToken(GetCurrentProcess(), 0x28, out IntPtr tok);
        LookupPrivilegeValue(null, name, ref LUID l);
        TOKEN_PRIVILEGES tp; tp.Count = 1; tp.Priv.Luid = l; tp.Priv.Attr = SE_PRIV_ENABLED;
        AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }

    public static string ForceDelete(string subkey) {
        try {
            Enable("SeTakeOwnershipPrivilege");
            Enable("SeRestorePrivilege");
            var sys = new SecurityIdentifier("S-1-5-18");
            // take ownership
            using (var k = Registry.LocalMachine.OpenSubKey(subkey, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.TakeOwnership)) {
                var a = k.GetAccessControl(AccessControlSections.Owner);
                a.SetOwner(sys);
                k.SetAccessControl(a);
            }
            // grant full control
            using (var k = Registry.LocalMachine.OpenSubKey(subkey, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.ChangePermissions)) {
                var a = k.GetAccessControl();
                a.SetAccessRule(new RegistryAccessRule(new SecurityIdentifier("S-1-5-32-544"), RegistryRights.FullControl, InheritanceFlags.ContainerInherit, PropagationFlags.None, AccessControlType.Allow));
                k.SetAccessControl(a);
            }
            // delete (open with Delete)
            Registry.LocalMachine.DeleteSubKeyTree(subkey, false);
            return "DELETED";
        } catch (Exception e) { return "FAIL: " + e.Message; }
    }
}
"@

# Recurse the Appx store; the per-user key S-1-5-21-... holds the DAI bundle subtree.
$storeRoot = "SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"
$base = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($storeRoot)
$targets = @()
foreach ($userSub in $base.GetSubKeyNames()) {
    $uk = "$storeRoot\$userSub"
    $ukey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($uk)
    if ($ukey) {
        foreach ($pkg in $ukey.GetSubKeyNames()) {
            if ($pkg -match "DesktopAppInstaller") {
                $targets += "$uk\$pkg"
            }
        }
        $ukey.Close()
    }
}
$base.Close()
# also the Deprovisioned marker
$dep = "$storeRoot\Deprovisioned\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
if ([Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($dep) -ne $null) { $targets += $dep }

W "targets: $($targets.Count)"
foreach ($t in $targets) {
    $r = [RegTake]::ForceDelete($t)
    W "  $t -> $r"
}

W "`n=== verify ==="
$still = Get-AppxPackage -AllUsers -Name "Microsoft.DesktopAppInstaller" -EA SilentlyContinue
W "DAI present: $([bool]$still)"
W "winget cmd: $([bool](Get-Command winget -EA SilentlyContinue))"
# re-scan registry
$rem = 0
$b2 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($storeRoot)
foreach ($u in $b2.GetSubKeyNames()) {
    $uk2 = $b2.OpenSubKey($u)
    if ($uk2) { foreach ($p in $uk2.GetSubKeyNames()) { if ($p -match "DesktopAppInstaller") { $rem++ } }; $uk2.Close() }
}
$b2.Close()
W "remaining DAI reg keys: $rem"
W "DONE"