$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\install-kb5007651-log.txt"
"=== install KB5007651 Windows Security app update $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

$url = "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/defu/2025/04/securityhealthsetup_2e7aca853436ee85bf95413aa3471540212da972.exe"
$dst = "$H\Downloads\SecurityHealthSetup.exe"

W "downloading SecurityHealthSetup (KB5007651) ARM64..."
try {
    Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing -EA Stop
    W "downloaded: $([math]::Round((Get-Item $dst).Length/1MB)) MB"
} catch { W "download fail: $($_.Exception.Message)"; "FAIL" | Out-File "$H\Downloads\kb-dl-failed.flag"; exit 1 }

W "`nrunning installer (silent)..."
$p = Start-Process $dst -ArgumentList "/quiet","/norestart" -Wait -PassThru -EA Stop
W "installer exit: $($p.ExitCode)"

Start-Sleep 4
W "`n=== verify ==="
$pkg = Get-AppxPackage -AllUsers -Name "Microsoft.SecHealthUI" -EA SilentlyContinue
W "SecHealthUI: $(if($pkg){$pkg.PackageFullName}else{'absent'})"
$host = Test-Path "C:\Windows\SystemApps\Microsoft.WindowsDefenderSecurityCenter_8wekyb3d8bbwe"
W "WindowsDefenderSecurityCenter SystemApps: $host"
W "SecurityHealthService: $((Get-Service SecurityHealthService -EA SilentlyContinue).Status)"
# windowsdefender:// protocol command restored?
$cmd = (Get-ItemProperty "HKLM:\SOFTWARE\Classes\windowsdefender\shell\open\command" -EA SilentlyContinue).'(default)'
W "protocol command: [$cmd]"

W "`n=== relaunch test ==="
Start-Process "windowsdefender://" -EA SilentlyContinue
Start-Sleep 5
$proc = Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -match "SecHealth|SecurityHealth" }
W "procs: $(if($proc){($proc|Select -ExpandProperty ProcessName) -join ','}else{'none'})"
W "DONE"
Copy-Item $log "\\Mac\Home\Downloads\vm-install-kb5007651-log.txt" -Force