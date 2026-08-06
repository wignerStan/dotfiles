$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\restore-webview-log.txt"
"=== restore WebView for Security GUI $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# The Windows Security app (SecHealthClient) renders via the Edge WebView / WinUI WebView.
# We removed Edge (MicrosoftEdge.Stable) + SecHealthClient. To use the Defender GUI to
# toggle Tamper Protection, we need: MicrosoftEdge (the runtime) + SecHealthClient back.
# Re-add them from the system component store via DISM/Get-AppxPackage.

W "=== what's the source for Edge/SecHealthClient? ==="
# The system image keeps a staged copy. Find it:
$prov = Get-AppxProvisionedPackage -Online -EA SilentlyContinue | Where-Object { $_.DisplayName -match 'Edge|SecHealthClient|WindowsDefender' }
foreach ($p in $prov) { W "provisioned: $($p.DisplayName)" }

# Re-register Edge + SecHealthClient from the staged component store.
# Get-AppxPackage -AllUsers won't list removed system packages; use DISM to re-add.
W "`n=== re-add via DISM Add-ProvisionedAppxPackage (if staged) or re-register ==="

# Method: re-register from the WindowsApps staged location if present, else use
# the Windows Security app directly. First, check WinDefend Security Center.
$sechealth = Get-AppxPackage -AllUsers -Name "Microsoft.SecHealthClient" -EA SilentlyContinue
W "SecHealthClient present: $([bool]$sechealth)"

# Try Add-AppxPackage with the system stub for SecHealthClient
$systemApps = "C:\Windows\SystemApps"
$shPath = Get-ChildItem $systemApps -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "SecHealthClient|WindowsDefenderSecurityCenter" } | Select-Object -First 1
W "SecHealthClient SystemApps folder: $(if($shPath){$shPath.FullName}else{'absent'})"
if ($shPath) {
    $manifest = Join-Path $shPath.FullName "AppxManifest.xml"
    if (Test-Path $manifest) {
        try { Add-AppxPackage -Register $manifest -DisableDevelopmentMode -EA Stop; W "re-registered SecHealthClient from SystemApps manifest" }
        catch { W "SecHealthClient re-register fail: $($_.Exception.Message)" }
    }
}

# Edge: the Win11 system Edge (not the Win32 Edge Stable) — re-register from SystemApps
$edgePath = Get-ChildItem $systemApps -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "MicrosoftEdge" } | Select-Object -First 1
W "Edge SystemApps folder: $(if($edgePath){$edgePath.FullName}else{'absent'})"
if ($edgePath) {
    $manifest = Join-Path $edgePath.FullName "AppxManifest.xml"
    if (Test-Path $manifest) {
        try { Add-AppxPackage -Register $manifest -DisableDevelopmentMode -EA Stop; W "re-registered Edge from SystemApps manifest" }
        catch { W "Edge re-register fail: $($_.Exception.Message)" }
    }
}

W "`n=== verify ==="
W "SecHealthClient: $([bool](Get-AppxPackage -AllUsers -Name Microsoft.SecHealthClient -EA SilentlyContinue))"
W "Edge system: $([bool](Get-AppxPackage -AllUsers -Name Microsoft.MicrosoftEdge -EA SilentlyContinue))"
W "DONE"