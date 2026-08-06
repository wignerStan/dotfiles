$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\rm-dai-log.txt"
"=== force-remove DesktopAppInstaller folder $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8

$loc = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.29.280.0_arm64__8wekyb3d8bbwe"
if (-not (Test-Path $loc)) { "already gone" | Add-Content -Path $log -Encoding UTF8; "DONE" | Add-Content -Path $log -Encoding UTF8; exit }

$sz = [math]::Round((Get-ChildItem $loc -Recurse -Force -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1MB,1)
"folder: $loc ($sz MB)" | Add-Content -Path $log -Encoding UTF8

# take ownership recursively, grant Administrators+SYSTEM full control, then delete.
# Run as SYSTEM (this task runs SYSTEM) — SYSTEM can take ownership from TrustedInstaller.
"taking ownership..." | Add-Content -Path $log -Encoding UTF8
$tk = & takeown.exe /f $loc /r /d Y 2>&1 | Out-String
"takeown exit: $LASTEXITCODE" | Add-Content -Path $log -Encoding UTF8

"granting permissions..." | Add-Content -Path $log -Encoding UTF8
$ic = & icacls.exe $loc /grant "*S-1-5-18:(OI)(CI)F" "Administrators:(OI)(CI)F" /t /c /q 2>&1 | Out-String
"icacls exit: $LASTEXITCODE" | Add-Content -Path $log -Encoding UTF8

# clear read-only/attribute flags then delete
"clearing attributes + delete..." | Add-Content -Path $log -Encoding UTF8
attrib -r -s -h "$loc\*" /s /d 2>&1 | Out-Null
Remove-Item -LiteralPath $loc -Recurse -Force -EA SilentlyContinue
"gone after delete: $( -not (Test-Path $loc))" | Add-Content -Path $log -Encoding UTF8

# belt-and-suspenders: rd via cmd (sometimes succeeds where Remove-Item fails)
if (Test-Path $loc) {
    & cmd.exe /c "rd /s /q `"$loc`"" 2>&1 | Out-Null
    "gone after rd: $( -not (Test-Path $loc))" | Add-Content -Path $log -Encoding UTF8
}

# final: also strip the staged/config registry entries (so it doesn't "heal")
foreach ($root in @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Staged",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Config"
)) {
    Get-ChildItem $root -EA SilentlyContinue | Where-Object { $_.PSChildName -match 'DesktopAppInstaller' } | ForEach-Object {
        Remove-Item -LiteralPath $_.PSPath -Recurse -Force -EA SilentlyContinue
        "removed reg: $($_.PSChildName)" | Add-Content -Path $log -Encoding UTF8
    }
}

"C free: {0:N1} GB" -f ((Get-PSDrive C).Free/1GB) | Add-Content -Path $log -Encoding UTF8
"DONE" | Add-Content -Path $log -Encoding UTF8