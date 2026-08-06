$U = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue).DefaultUserName
if (-not $U) { $U = $env:USERNAME }
$H = "C:\Users\$U"
$log = "$H\finalcheck-log.txt"
function W($m) { Add-Content $log "$m"; Write-Host $m }
Set-Content $log "final clean check"
W ("appx total: {0}" -f (Get-AppxPackage -AllUsers -EA SilentlyContinue).Count)
W ("Edge appx: {0}" -f [bool](Get-AppxPackage -AllUsers -EA SilentlyContinue *MicrosoftEdge.Stable*))
W ("msedge.exe: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'))
W ("EdgeCore/WebView dirs: {0}" -f ((Test-Path 'C:\Program Files (x86)\Microsoft\EdgeCore') -or (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView')))
W ("EdgeUpdate: {0}" -f ((Test-Path 'C:\Program Files (x86)\Microsoft\EdgeUpdate') -or (Test-Path 'C:\ProgramData\Microsoft\EdgeUpdate')))
W ("SecHealthUI files: {0}" -f [bool](Get-ChildItem 'C:\Program Files\WindowsApps' -Directory -Filter '*SecHealthUI*' -EA SilentlyContinue))
W ("StartMenu Edge/Security links: {0}" -f [bool](Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Recurse -EA SilentlyContinue | Where-Object { $_.Name -match 'Edge|Security|安全|Defender' }))
W ("defender realtime off: {0}" -f (Get-MpPreference -EA SilentlyContinue).DisableRealtimeMonitoring)
W ("git: {0}" -f [bool](Test-Path "$H\.local\mingit\cmd\git.exe"))
W ("uv: {0}" -f [bool](Test-Path "$H\.local\uv\uv.exe"))
W ("python aarch64: {0}" -f [bool](Get-ChildItem "$H\AppData\Roaming\uv\python" -Directory -Filter '*aarch64*' -EA SilentlyContinue))
W ("7z: {0}" -f (Test-Path "$H\AppData\Local\7-Zip\7z.exe"))
W ("geek: {0}" -f (Test-Path "$H\AppData\Local\GeekUninstaller\geek.exe"))
W ("Weisoft: {0}" -f (Test-Path 'C:\Weisoft Stock(x64)\WinStock.exe'))
W ("WebView2: {0}" -f (Test-Path 'C:\Program Files (x86)\Microsoft\EdgeWebView\Application\150.0.4078.105\msedgewebview2.exe'))
W ("Kuaiji: {0}" -f (Test-Path 'C:\徽商期货快期V3'))
W ("Machine PATH tools: {0}" -f [bool](([Environment]::GetEnvironmentVariable('Path','Machine') -match 'mingit')))
W ("privacy policy: {0}" -f ((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE' -Name DisablePrivacyExperience -EA SilentlyContinue).DisablePrivacyExperience))
W "DONE"