$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\Downloads\security-deps-log.txt"
"=== Security UI dependency check $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# The Windows Security app = SecurityHealthSystray.exe launcher + SecHealthUI Appx
# which renders via WinUI WebView (needs Microsoft.UI.Xaml + WinAppRuntime + Edge WebView2).
W "=== 1. launcher + service ==="
W "SecurityHealthSystray.exe: $(Test-Path 'C:\Windows\System32\SecurityHealthSystray.exe')"
W "SecurityHealthService: $(if((Get-Service SecurityHealthService -EA SilentlyContinue)){'present'}else{'ABSENT'})"
W "SecurityHealthProxyStub: $(Test-Path 'C:\Windows\System32\SecurityHealthProxyStub.dll')"

W "`n=== 2. SecHealthUI Appx state ==="
$sh = Get-AppxPackage -AllUsers -Name "Microsoft.SecHealthUI" -EA SilentlyContinue
W "SecHealthUI: $(if($sh){$sh.PackageFullName+' @ '+$sh.InstallLocation}else{'absent'})"
$sh2 = Get-AppxPackage -AllUsers -EA SilentlyContinue | Where-Object { $_.Name -match "SecHealth|DefenderSecurity" }
foreach ($p in $sh2) { W "  pkg: $($p.PackageFullName)" }

W "`n=== 3. WinUI / WebView2 runtime components ==="
foreach ($n in "Microsoft.UI.Xaml.2.7","Microsoft.UI.Xaml.2.8","Microsoft.UI.Xaml.CBS","Microsoft.Win32WebViewHost","Microsoft.Web.View","Microsoft.MicrosoftEdge","Microsoft.MicrosoftEdge.Stable","Microsoft.MicrosoftEdgeDevToolsClient","Microsoft.WindowsAppRuntime") {
    $p = Get-AppxPackage -AllUsers -Name $n -EA SilentlyContinue
    W "  $n : $(if($p){'present'}else{'ABSENT'})"
}

W "`n=== 4. try launching + capture errors ==="
Start-Process "C:\Windows\System32\SecurityHealthSystray.exe" -EA SilentlyContinue
Start-Process "windowsdefender://" -EA SilentlyContinue
Start-Sleep 4
$procs = Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -match "SecurityHealth|SecHealthUI|Win32WebViewHost" }
W "running procs: $(if($procs){($procs|Select -ExpandProperty ProcessName) -join ','}else{'NONE'})"

W "`n=== 5. event log: AppX / DCOM / App errors (last 5 min) ==="
$ev = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddMinutes(-5)} -MaxEvents 15 -EA SilentlyContinue | Where-Object { $_.Message -match "SecHealth|SecurityHealth|Defender|WebView|AppX" }
foreach ($e in $ev) { W "  [$($e.Id)] $($e.Message.Substring(0,[Math]::Min(200,$e.Message.Length)))" }

W "DONE"