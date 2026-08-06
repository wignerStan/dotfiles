$p=Get-MpPreference -EA SilentlyContinue
Write-Host ("realtime_disabled=" + $p.DisableRealtimeMonitoring)
$svc=Get-Service WinDefend -EA SilentlyContinue
Write-Host ("defender_service=" + $svc.Status)
$ms=Get-MpComputerStatus -EA SilentlyContinue
Write-Host ("ams_engine_enabled=" + $ms.AMServiceEnabled)
Write-Host ("tamper=" + $ms.IsTamperProtected)
Write-Host "DRIVES:"
Get-PSDrive -PSProvider FileSystem | Select-Object Name,Root,Used,Free | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Kuaiji source exists on X:"
Write-Host ("x_kuaiji=" + (Test-Path 'X:\徽商期货快期V3'))
Write-Host "Mac home mapping:"
cmd /c net use 2>&1 | Out-String | Write-Host
