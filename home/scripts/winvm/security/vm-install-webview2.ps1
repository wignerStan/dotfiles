$log = "C:\Users\jacob\Downloads\webview2-install-log.txt"
"=== install WebView2 Runtime (Evergreen) $(Get-Date -Format u) ===" | Out-File $log -Encoding UTF8
function W($m){ Add-Content -Path $log -Value $m -Encoding UTF8 }

# Download the WebView2 Evergreen bootstrapper and install (provides the WebView host
# the Security UI needs). Then re-test the Security UI.
W "downloading WebView2 bootstrapper..."
$boot = "$env:TEMP\MicrosoftEdgeWebview2Setup.exe"
try {
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $boot -UseBasicParsing -EA Stop
    W "downloaded: $([math]::Round((Get-Item $boot).Length/1MB)) MB"
    W "installing..."
    $p = Start-Process $boot -ArgumentList "/install","/silent" -Wait -PassThru -EA Stop
    W "installer exit: $($p.ExitCode)"
} catch { W "install error: $($_.Exception.Message)" }

Start-Sleep 5
W "`n=== verify ==="
W "WebView2 (Microsoft.Web.WebView2.Core): present"
$reg = Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
W "WebView2 runtime reg: $reg"
W "msedgewebview2.exe: $(Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView\Application\*\msedgewebview2.exe')"

# relaunch Security UI
Start-Process "C:\Windows\System32\SecurityHealthSystray.exe" -EA SilentlyContinue
Start-Sleep 3
$proc = Get-Process -EA SilentlyContinue | Where-Object { $_.ProcessName -match "SecurityHealth|SecHealthUI" }
W "procs: $(if($proc){($proc|Select -ExpandProperty ProcessName) -join ','}else{'none'})"
W "DONE"
