$py = & uv python find cpython-3.14-windows-aarch64-none
$site = Join-Path (Split-Path $py) 'Lib\site-packages'
Copy-Item "\\Mac\Home\pywin32_postinstall.py" "$site\pywin32_postinstall.py" -Force
Write-Host "=== run postinstall -silent -install ==="
& $py "$site\pywin32_postinstall.py" -silent -install 2>&1 | Select-Object -Last 3
Write-Host "=== retry import ==="
& $py -c "import win32ui; print('win32ui OK')"
& $py -c "import pywinauto; print('pywinauto import OK')"
