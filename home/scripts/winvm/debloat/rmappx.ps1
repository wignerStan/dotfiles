$ErrorActionPreference = 'Continue'
$log = 'C:\Users\jacob\rmappx-log.txt'
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "rmappx start as $env:USERNAME"

$targets = @('Microsoft.MicrosoftEdge.Stable', 'Microsoft.SecHealthUI', 'Microsoft.MicrosoftEdgeDevToolsClient')

foreach ($t in $targets) {
    W "=== $t ==="
    $pkg = Get-AppxPackage -AllUsers -EA SilentlyContinue | Where-Object { $_.Name -eq $t }
    if (-not $pkg) { W "  already gone"; continue }
    # try normal removal
    try {
        $pkg | Remove-AppxPackage -AllUsers -EA Stop
        W "  Remove-AppxPackage OK"
    } catch { W "  Remove-AppxPackage failed: $($_.Exception.Message.Substring(0, [Math]::Min(120, $_.Exception.Message.Length)))" }
    # still present?
    $pkg2 = Get-AppxPackage -AllUsers -EA SilentlyContinue | Where-Object { $_.Name -eq $t }
    if (-not $pkg2) { W "  gone after API removal"; continue }
    # doc method: takeown files + reg delete
    W "  doc method: takeown + registry delete"
    $loc = $pkg2.InstallLocation
    if ($loc -and (Test-Path $loc)) {
        takeown.exe /f $loc /r /d Y 2>&1 | Out-Null
        icacls.exe $loc /grant "*S-1-5-18:(OI)(CI)F" "Administrators:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
        Remove-Item -LiteralPath $loc -Recurse -Force -EA SilentlyContinue
        W ("  files gone: {0}" -f (-not (Test-Path $loc)))
    } else { W "  install location: $loc" }
    # registry: AppxAllUserStore
    $store = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
    $keys = reg query $store /s /f $t /k 2>$null | Select-String $t
    foreach ($line in $keys) {
        $k = ($line.Line -split '\s{2,}')[-1]
        if ($k -match 'AppxAllUserStore') {
            reg delete $k /f 2>&1 | Out-Null
            W "  reg deleted: $k"
        }
    }
    W "  after: $([bool](Get-AppxPackage -AllUsers -EA SilentlyContinue | Where-Object { $_.Name -eq $t }))"
}

# EdgeUpdate dirs — retry deletion (services already disabled/stopped)
W "=== EdgeUpdate dirs retry ==="
foreach ($d in @('C:\Program Files (x86)\Microsoft\EdgeUpdate','C:\ProgramData\Microsoft\EdgeUpdate')) {
    if (Test-Path $d) {
        takeown.exe /f $d /r /d Y 2>&1 | Out-Null
        icacls.exe $d /grant "*S-1-5-18:(OI)(CI)F" "Administrators:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
        Remove-Item -LiteralPath $d -Recurse -Force -EA SilentlyContinue
        W ("  {0}: gone={1}" -f $d, (-not (Test-Path $d)))
    }
}
W "DONE"
