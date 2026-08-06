@echo off
C:\Windows\SysWOW64\regsvr32.exe /s "C:\Weisoft Stock(x64)\EditGridLib.ocx"
echo EDITGRID_EXIT=%ERRORLEVEL%
C:\Windows\SysWOW64\regsvr32.exe /s "C:\Weisoft Stock(x64)\MSHFlexGridPrint.dll"
echo MSHFLEX_EXIT=%ERRORLEVEL%
C:\Windows\SysWOW64\regsvr32.exe /s "C:\Weisoft Stock(x64)\EDITGRIDCTRLLIB.OCX"
echo CTRLLIB_EXIT=%ERRORLEVEL%
