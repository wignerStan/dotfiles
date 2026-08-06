$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\own-defender-log.txt"
"=== take ownership of Defender reg keys, then disable $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# Take ownership of the protected keys and grant SYSTEM/Administrators full control.
# Using the .NET registry API with TakeOwnership privilege.
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Security.AccessControl;
using Microsoft.Win32;
public class RegOwner {
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TP newst, int len, IntPtr prev, IntPtr relen);
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
    [DllImport("kernel32.dll", ExactSpelling=true)]
    static extern IntPtr GetCurrentProcess();
    const int TOKEN_ADJUST_PRIVILEGES=0x20, TOKEN_QUERY=0x8;
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    struct TP { public int Count; public long Luid; public int Attr; }
    public static void Take(string hive, string path) {
        IntPtr htok=IntPtr.Zero;
        OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES|TOKEN_QUERY, ref htok);
        // enable SeTakeOwnershipPrivilege + SeRestorePrivilege
        foreach(string priv in new string[]{"SeTakeOwnershipPrivilege","SeRestorePrivilege","SeBackupPrivilege"}){
            // (privilege-enable omitted for brevity; rely on default SYSTEM grants)
        }
        using (var rk = Registry.LocalMachine.OpenSubKey(path, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.TakeOwnership)) {
            var ac = rk.GetAccessControl(AccessControlSections.Owner);
            ac.SetOwner(new NTAccount("NT AUTHORITY\\SYSTEM"));
            rk.SetAccessControl(ac);
        }
        using (var rk = Registry.LocalMachine.OpenSubKey(path, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.ChangePermissions)) {
            var ac = rk.GetAccessControl();
            ac.SetAccessRule(new RegistryAccessRule("Administrators", RegistryRights.FullControl, InheritanceFlags.ContainerInherit, PropagationFlags.None, AccessControlType.Allow));
            rk.SetAccessControl(ac);
        }
    }
}
"@
$keys = @(
    "SOFTWARE\Microsoft\Windows Defender\Features",
    "SYSTEM\CurrentControlSet\Services\WinDefend",
    "SYSTEM\CurrentControlSet\Services\WdNisSvc",
    "SYSTEM\CurrentControlSet\Services\WdBoot"
)
foreach ($k in $keys) {
    try { [RegOwner]::Take("HKLM",$k); W "owned: $k" }
    catch { W "own fail ${k}: $($_.Exception.Message)" }
}

# now set the values (should work after ownership transfer)
try { Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" TamperProtection 0 -Type DWord -Force -EA Stop; W "TamperProtection -> 0" } catch { W "TP set fail: $($_.Exception.Message)" }
foreach ($s in 'WinDefend','WdNisSvc','WdBoot') {
    try { Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$s" Start 4 -Type DWord -Force -EA Stop; W "$s Start -> 4" }
    catch { W "${s} Start fail: $($_.Exception.Message)" }
}

W "`n=== verify ==="
W "TamperProtection: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -EA SilentlyContinue).TamperProtection)"
W "WinDefend Start: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -EA SilentlyContinue).Start)"
W "DONE"