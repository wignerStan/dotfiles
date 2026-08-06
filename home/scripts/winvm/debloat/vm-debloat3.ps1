$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
#powershell
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$log = "$H\Downloads\debloat3-log.txt"
"=== Win11Debloat corrected $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m) { Add-Content -Path $log -Value $m }

$s = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Win11Debloat.ps1' -UseBasicParsing
W "Downloaded v$($s -match 'Version.*?=.*?\"(.*?)\"' | Out-Null; $Matches[1])"

$flags = @(
    '-Silent',
    '-RunDefaults',
    '-AppRemovalTarget','AllUsers',
    '-DisableTelemetry',
    '-DisableSearchHistory',
    '-DisableBing',
    '-DisableNotifications',
    '-DisableStoreSearchSuggestions',
    '-DisableDesktopSpotlight',
    '-DisableLockscreenTips',
    '-DisableSuggestions',
    '-DisableLocationServices',
    '-DisableFindMyDevice',
    '-DisableEdgeAds',
    '-DisableSettingsHome',
    '-ShowHiddenFolders',
    '-ShowKnownFileExt',
    '-EnableDarkMode',
    '-DisableStartRecommended',
    '-DisableStartPhoneLink',
    '-DisableCopilot',
    '-DisableRecall',
    '-DisableClickToDo',
    '-DisableAISvcAutoStart',
    '-DisablePaintAI',
    '-DisableNotepadAI',
    '-DisableEdgeAI',
    '-DisableWidgets',
    '-HideChat',
    '-EnableEndTask',
    '-RevertContextMenu',
    '-HideHome',
    '-HideGallery',
    '-ExplorerToThisPC',
    '-ForceRemoveEdge'
)

W "Running with $($flags.Count) flags"
try {
    $output = & ([scriptblock]::Create($s)) @flags 2>&1
    foreach ($line in $output) { W "$line" }
    W "DEBLOAT DONE"
} catch {
    W "ERROR: $($_.Exception.Message)"
}

# OneDrive removal
W "`n=== OneDrive ==="
Get-Process OneDrive -EA SilentlyContinue | Stop-Process -Force
if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
    & "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /uninstall 2>&1 | Out-Null
    W "OneDrive uninstalled (SysWOW64)"
} elseif (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
    & "$env:SystemRoot\System32\OneDriveSetup.exe" /uninstall 2>&1 | Out-Null
    W "OneDrive uninstalled (System32)"
} else { W "OneDrive already gone" }

# WSearch
W "`n=== WSearch ==="
Stop-Service WSearch -Force -EA SilentlyContinue
Set-Service WSearch -StartupType Disabled -EA SilentlyContinue
W "WSearch disabled"

# Summary
W "`n=== Remaining Appx ==="
$pkgs = Get-AppxPackage -EA SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object
foreach ($p in $pkgs) { W "  $p" }
W "Total: $($pkgs.Count)"
W "DONE"