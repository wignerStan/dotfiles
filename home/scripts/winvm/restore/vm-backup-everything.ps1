$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\backup-everything-log.txt"
"=== backup jacob data + registry $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# ── 1. Export key registry hives ──
W "=== exporting registry ==="
$regDst = "\\Mac\Home\Downloads\vm-backup\registry"
New-Item -ItemType Directory -Force -Path $regDst | Out-Null

# Full hives (SYSTEM, SOFTWARE, SECURITY — for reference)
& reg.exe export "HKLM\SOFTWARE" "$regDst\HKLM-SOFTWARE.reg" /y 2>&1 | Out-Null
W "  HKLM\SOFTWARE exported"
& reg.exe export "HKLM\SYSTEM" "$regDst\HKLM-SYSTEM.reg" /y 2>&1 | Out-Null
W "  HKLM\SYSTEM exported"

# Targeted app keys (金字塔, 快期, Office, chezmoi, trade-related)
$targetKeys = @(
    @{Name="Weisoft-Stock"; Path="HKLM\SOFTWARE\Weisoft"},
    @{Name="Weisoft-WOW64"; Path="HKLM\SOFTWARE\WOW6432Node\Weisoft"},
    @{Name="Trade-uninstall"; Path="HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"},
    @{Name="Trade-uninstall-WOW64"; Path="HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"},
    @{Name="jacob-uninstall"; Path="HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"},
    @{Name="Office"; Path="HKLM\SOFTWARE\Microsoft\Office"},
    @{Name="Office-WOW64"; Path="HKLM\SOFTWARE\WOW6432Node\Microsoft\Office"},
    @{Name="Run-HKLM"; Path="HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"},
    @{Name="Run-HKCU"; Path="HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"},
    @{Name="jacob-software"; Path="HKCU\SOFTWARE"},
    @{Name="NetworkList"; Path="HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList"},
    @{Name="Winlogon"; Path="HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"}
)
foreach ($k in $targetKeys) {
    $file = "$regDst\$($k.Name).reg"
    & reg.exe export $k.Path $file /y 2>&1 | Out-Null
    if (Test-Path $file) { W "  $($k.Name): exported ($([math]::Round((Get-Item $file).Length/1KB))KB)" }
    else { W "  $($k.Name): FAILED" }
}

# ── 2. Copy jacob user profile ──
W "`n=== copying jacob profile ==="
$profileDst = "\\Mac\Home\Downloads\vm-backup\jacob-profile"
New-Item -ItemType Directory -Force -Path $profileDst | Out-Null

# Key dirs to preserve (skip huge/temp caches)
$dirs = @{
    "Desktop"    = "$H\Desktop"
    "Documents"  = "$H\Documents"
    "Downloads"  = "$H\Downloads"
    "AppData-Roaming" = "$H\AppData\Roaming"
    "ssh"        = "$H\.ssh"
    "chezmoi"    = "$H\.config\chezmoi"
    "local-bin"  = "$H\.local"
}

foreach ($name in $dirs.Keys) {
    $src = $dirs[$name]
    if (Test-Path $src) {
        $dst = "$profileDst\$name"
        W "  copying $name ($src)..."
        try {
            Copy-Item $src $dst -Recurse -Force -EA SilentlyContinue
            $sz = [math]::Round((Get-ChildItem $dst -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1MB, 1)
            W "    OK ($sz MB)"
        } catch { W "    error: $($_.Exception.Message)" }
    } else { W "  $name: not found ($src)" }
}

# AppData\Local — selectively (skip caches, temp)
W "`n=== selective AppData\Local ==="
$localPick = @(
    "$H\AppData\Local\Microsoft\Office",
    "$H\AppData\Local\Packages"
)
foreach ($p in $localPick) {
    if (Test-Path $p) {
        $rel = $p.Replace("$H\AppData\Local\", "")
        $dst = "$profileDst\AppData-Local\$rel"
        W "  copying $rel..."
        Copy-Item $p $dst -Recurse -Force -EA SilentlyContinue
        W "    done"
    }
}

# ── 3. 金字塔 data (already backed up, but double-check) ──
W "`n=== 金字塔 data ==="
$jztSrc = "C:\Weisoft Stock(x64)"
if (Test-Path $jztSrc) {
    $jztDst = "\\Mac\Home\Downloads\vm-backup\jzt"
    New-Item -ItemType Directory -Force -Path $jztDst | Out-Null
    W "  金字塔 exists — already backed up to jzt-full-backup inside VM"
    W "  also copying config files..."
    Get-ChildItem $jztSrc -EA SilentlyContinue | Where-Object { $_.Extension -in ".xml",".ini",".dat",".cfg" } | ForEach-Object {
        Copy-Item $_.FullName $jztDst -Force -EA SilentlyContinue
    }
    W "  config files copied"
}

# ── 4. 快期 ──
W "`n=== 快期 ==="
$qSrc = "C:\" + [char]0x5FBD + [char]0x5546 + [char]0x671F + [char]0x8D27 + [char]0x5FEB + [char]0x671F + "V3"
if (Test-Path $qSrc) { W "  快期 exists at $qSrc" } else { W "  快期 not found" }

# ── 5. installed software inventory ──
W "`n=== installed software list ==="
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Sort-Object DisplayName |
    ForEach-Object { W "  $($_.DisplayName) | $($_.DisplayVersion) | $($_.InstallLocation)" }

W "`nDONE"
Copy-Item $log "\\Mac\Home\Downloads\vm-backup-log.txt" -Force