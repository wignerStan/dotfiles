@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -AllUsers *OneDrive* | Remove-AppxPackage -AllUsers; Write-Host 'OneDrive removed'; Get-AppxPackage -AllUsers *OneDrive* | Select-Object -ExpandProperty Name; if (-not $?) { Write-Host 'VERIFIED: OneDrive gone' }"
