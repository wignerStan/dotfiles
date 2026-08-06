$log = "C:\Users\jacob\Downloads\own-defender2-log.txt"
"=== take ownership w/ privilege enabled $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Security.AccessControl;
using Microsoft.Win32;

public class RegOwner {
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TOKEN_PRIVILEGES newst, int len, IntPtr prev, IntPtr relen);
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
    [DllImport("kernel32.dll", ExactSpelling=true)]
    static extern IntPtr GetCurrentProcess();
    const int TOKEN_QUERY=0x0008, TOKEN_ADJUST_PRIVILEGES=0x0020;
    const int SE_PRIVILEGE_ENABLED=0x00000002;
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    internal struct TOKEN_PRIVILEGES { public int PrivilegeCount; public int LuidLow; public int LuidHigh; public int Attributes; }

    static void EnablePriv(string name) {
        IntPtr htok = IntPtr.Zero;
        if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES|TOKEN_QUERY, ref htok)) return;
        long luid = 0;
        LookupPrivilegeValue(null, name, ref luid);
        var tp = new TOKEN_PRIVILEGES();
        tp.PrivilegeCount = 1;
        tp.Attributes = SE_PRIVILEGE_ENABLED;
        tp.LuidLow = (int)(luid & 0xFFFFFFFF);
        tp.LuidHigh = (int)(luid >> 32);
        AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }

    public static string Take(string path) {
        try {
            // enable the privileges FIRST
            EnablePriv("SeTakeOwnershipPrivilege");
            EnablePriv("SeRestorePrivilege");
            EnablePriv("SeBackupPrivilege");
            EnablePriv("SeSecurityPrivilege");

            // take ownership
            using (var rk = Registry.LocalMachine.OpenSubKey(path, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.TakeOwnership)) {
                var ac = rk.GetAccessControl(AccessControlSections.Owner);
                ac.SetOwner(new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null));
                rk.SetAccessControl(ac);
            }
            // grant full control
            using (var rk = Registry.LocalMachine.OpenSubKey(path, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.ChangePermissions)) {
                var ac = rk.GetAccessControl();
                ac.SetAccessRule(new RegistryAccessRule(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null), RegistryRights.FullControl, InheritanceFlags.ContainerInherit, PropagationFlags.None, AccessControlType.Allow));
                rk.SetAccessControl(ac);
            }
            return "OK";
        } catch (Exception e) { return e.Message; }
    }
}
"@

$keys = @(
    "SOFTWARE\Microsoft\Windows Defender\Features",
    "SOFTWARE\Policies\Microsoft\Windows Defender",
    "SYSTEM\CurrentControlSet\Services\WinDefend",
    "SYSTEM\CurrentControlSet\Services\WdNisSvc",
    "SYSTEM\CurrentControlSet\Services\WdBoot"
)
foreach ($k in $keys) {
    $r = [RegOwner]::Take($k)
    W "own $k -> $r"
}

# now set the values
try { Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" TamperProtection 0 -Type DWord -Force -EA Stop; W "TamperProtection -> 0" } catch { W "TP set fail: $($_.Exception.Message)" }
foreach ($s in 'WinDefend','WdNisSvc','WdBoot') {
    try { Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$s" Start 4 -Type DWord -Force -EA Stop; W "$s Start -> 4" }
    catch { W "${s} Start fail: $($_.Exception.Message)" }
}

W "`n=== verify ==="
W "TamperProtection: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -EA SilentlyContinue).TamperProtection)"
W "WinDefend Start: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -EA SilentlyContinue).Start)"
W "WdNisSvc Start: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc' -EA SilentlyContinue).Start)"
W "DONE"
