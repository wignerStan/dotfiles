$dt = Get-Date
Write-Host ("trim start: " + $dt)
Optimize-Volume -DriveLetter C -ReTrim -Verbose 4>&1 | Out-String | Write-Host
Write-Host ("trim done: " + (Get-Date))
