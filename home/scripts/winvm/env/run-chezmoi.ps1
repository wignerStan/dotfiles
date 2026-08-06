$env:HOME = 'C:\Users\jacob'
$env:USERPROFILE = 'C:\Users\jacob'
$env:APPDATA = 'C:\Users\jacob\AppData\Roaming'
$env:LOCALAPPDATA = 'C:\Users\jacob\AppData\Local'
& 'C:\Users\jacob\.local\chezmoi\chezmoi.exe' @args
exit $LASTEXITCODE
