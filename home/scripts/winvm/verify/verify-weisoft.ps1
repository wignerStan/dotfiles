$d = 'C:\Weisoft Stock(x64)'
if (Test-Path $d) {
    $sz = (Get-ChildItem $d -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host ("dest exists, {0} MB, files: {1}" -f [math]::Round($sz/1MB), (Get-ChildItem $d -Recurse -File -EA SilentlyContinue).Count)
    Write-Host ("WinStock.exe: {0}" -f (Test-Path "$d\WinStock.exe"))
    Write-Host ("FinanceData.xml: {0}" -f (Test-Path "$d\FinanceData.xml"))
    Write-Host ("FormulaDescription.ini: {0}" -f (Test-Path "$d\FormulaDescription.ini"))
    Write-Host ("PythonInfo.xml: {0}" -f (Test-Path "$d\PythonInfo.xml"))
} else { Write-Host "DEST MISSING" }
