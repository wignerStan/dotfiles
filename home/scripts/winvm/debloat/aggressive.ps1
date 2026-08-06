$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$H = 'C:\Users\jacob'
$log = "$H\aggressive-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "STEP0 start as $env:USERNAME"
$dRoot = Join-Path $H '.local\win11debloat'
$dScript = Join-Path $dRoot 'Win11Debloat.ps1'
W "STEP1 dRoot=$dRoot scriptExists=$(Test-Path $dScript)"
if (-not (Test-Path $dScript)) {
    W "STEP2 downloading..."
    try {
        $zip = Join-Path $env:TEMP 'win11debloat.zip'
        Invoke-WebRequest -Uri 'https://github.com/Raphire/Win11Debloat/archive/refs/heads/master.zip' -OutFile $zip -UseBasicParsing
        New-Item -ItemType Directory -Force -Path $dRoot | Out-Null
        Expand-Archive -Path $zip -DestinationPath $dRoot -Force
        Remove-Item $zip -Force
        $nested = Join-Path $dRoot 'Win11Debloat-master'
        if (Test-Path $nested) { Get-ChildItem $nested | Move-Item -Destination $dRoot -Force; Remove-Item $nested -Force }
        W "STEP3 downloaded, scriptExists=$(Test-Path $dScript)"
    } catch { W "DOWNLOAD FAIL: $($_.Exception.Message)" }
}
$flags = @{
    Silent = $true; CreateRestorePoint = $true; User = 'jacob'
    DisableTelemetry = $true; DisableSuggestions = $true; DisableBing = $true; DisableEdgeAds = $true
    DisableLockscreenTips = $true; RevertContextMenu = $true; ShowKnownFileExt = $true
    ShowHiddenFolders = $true; EnableDarkMode = $true
    RunDefaults = $true; AppRemovalTarget = 'AllUsers'; DisableCopilot = $true; DisableWidgets = $true
    DisableRecall = $true; DisableClickToDo = $true; DisableStoreSearchSuggestions = $true; DisableDesktopSpotlight = $true
    ForceRemoveEdge = $true
}
W "STEP4 invoking Win11Debloat (SYSTEM, -User jacob)..."
try {
    & $dScript @flags 2>&1 | ForEach-Object { Add-Content $log "    $_" }
    W "STEP5 done, exit=$LASTEXITCODE"
} catch { W "INVOKE FAIL: $($_.Exception.Message)" }
W "STEP6 END"
