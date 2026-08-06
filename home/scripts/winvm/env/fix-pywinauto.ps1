$py = & uv python find cpython-3.14-windows-aarch64-none
$site = Join-Path (Split-Path $py) 'Lib\site-packages'
$post = Join-Path $site 'pywin32_postinstall.py'
Write-Host "postinstall: $post"
& $py $post -install 2>&1 | Select-Object -Last 4
Write-Host "=== retry import ==="
& $py -c "import pywinauto; print('pywinauto import OK')"
