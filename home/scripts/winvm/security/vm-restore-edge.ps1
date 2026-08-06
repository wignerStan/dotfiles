$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\restore-edge-log.txt"
"=== restore system Edge (WebView for Security UI) $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# 1. Find the system Edge Appx in SystemApps / provisioned store
W "=== SystemApps Edge folders ==="
$edgeDirs = Get-ChildItem "C:\Windows\SystemApps" -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "MicrosoftEdge" }
foreach ($d in $edgeDirs) { W "  $($d.FullName)" }

W "`n=== provisioned Edge ==="
$prov = Get-AppxProvisionedPackage -Online -EA SilentlyContinue | Where-Object { $_.DisplayName -match "Edge" }
foreach ($p in $prov) { W "  $($p.DisplayName) | $($p.PackageName)" }

# 2. Re-register the system Edge from its manifest
W "`n=== re-register ==="
foreach ($d in $edgeDirs) {
    $m = Join-Path $d.FullName "AppxManifest.xml"
    if (Test-Path $m) {
        try {
            Add-AppxPackage -Register $m -DisableDevelopmentMode -EA Stop
            W "re-registered: $($d.Name)"
        } catch { W "fail $($d.Name): $($_.Exception.Message)" }
    }
}

# 3. If Edge was provisioned, use DISM to re-add it
$edgeProv = Get-AppxProvisionedPackage -Online -EA SilentlyContinue | Where-Object { $_.DisplayName -eq "Microsoft.MicrosoftEdge" } | Select-Object -First 1
if ($edgeProv) {
    W "`n=== DISM re-add Edge ==="
    $r = & dism.exe /Online /Add-AppxPackage /PackagePath:$edgeProv.InstallLocation 2>&1 | Out-String
    W $r
}

Start-Sleep 4
W "`n=== verify ==="
W "MicrosoftEdge: $(if((Get-AppxPackage -AllUsers -Name 'Microsoft.MicrosoftEdge' -EA SilentlyContinue)){'present'}else{'ABSENT'})"
# relaunch security UI
Start-Process "C:\Windows\System32\SecurityHealthSystray.exe" -EA SilentlyContinue
Start-Sleep 3
$proc = Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -match "SecurityHealth|SecHealthUI" }
W "procs: $(if($proc){($proc|Select -ExpandProperty ProcessName) -join ','}else{'none'})"
W "DONE"