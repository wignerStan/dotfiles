$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\host-infra.txt"
"" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

W "=== Windows Defender Program Files folder ==="
$wd = "C:\Program Files\Windows Defender"
W "exists: $(Test-Path $wd)"
if (Test-Path $wd) {
    W "contents:"
    Get-ChildItem $wd -EA SilentlyContinue | ForEach-Object { W "  $($_.Name) ($([math]::Round($_.Length/1KB))KB)" }
}

W "`n=== SecurityHealthSystray references (what does it need?) ==="
$st = "C:\Windows\System32\SecurityHealthSystray.exe"
W "systray exists: $(Test-Path $st)"
# what DLLs does it import?
W "imports (SecurityHealthCenter*, Defender*):"
$sys = "C:\Windows\System32"
Get-ChildItem $sys -Filter "SecurityHealth*.dll" -EA SilentlyContinue | ForEach-Object { W "  $($_.Name)" }
Get-ChildItem $sys -Filter "*DefenderSecurity*" -EA SilentlyContinue | ForEach-Object { W "  $($_.Name)" }

W "`n=== Windows Security SystemApps folder ==="
$saf = "C:\Windows\SystemApps\Microsoft.WindowsDefenderSecurityCenter_8wekyb3d8bbwe"
W "exists: $(Test-Path $saf)"
if (Test-Path $saf) { Get-ChildItem $saf -EA SilentlyContinue | Select-Object -First 8 | ForEach-Object { W "  $($_.Name)" } }

W "`n=== is WindowsDefenderSecurityCenter staged anywhere (DISM/WinSxS)? ==="
$prov = Get-AppxProvisionedPackage -Online -EA SilentlyContinue | Where-Object { $_.DisplayName -match "DefenderSecurity|SecHealth" }
foreach ($p in $prov) { W "provisioned: $($p.DisplayName) | $($p.PackageName) | $($p.InstallLocation)" }
$wsx = Get-ChildItem "C:\Windows\WinSxS" -Directory -EA SilentlyContinue | Where-Object { $_.Name -match "DefenderSecurity" } | Select-Object -First 3
foreach ($w in $wsx) { W "WinSxS: $($w.Name)" }
if (-not $wsx) { W "WinSxS: none" }

W "`n=== SecurityHealthService.exe (the new host) anywhere? ==="
Get-ChildItem "C:\Windows" -Recurse -Filter "SecurityHealthService.exe" -EA SilentlyContinue -Depth 3 | ForEach-Object { W "  $($_.FullName)" }
Get-ChildItem "C:\Program Files" -Recurse -Filter "SecurityHealthService.exe" -EA SilentlyContinue -Depth 3 | ForEach-Object { W "  $($_.FullName)" }

W "DONE"
Copy-Item $log "\\Mac\Home\Downloads\vm-host-infra.txt" -Force