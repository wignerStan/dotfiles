function Get-PEArch($path) {
    try {
        $fs = [System.IO.File]::OpenRead($path)
        $br = New-Object System.IO.BinaryReader($fs)
        $fs.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOff = $br.ReadInt32()
        $fs.Seek($peOff + 4, [System.IO.SeekOrigin]::Begin) | Out-Null
        $machine = $br.ReadUInt16()
        $fs.Close()
        switch ($machine) { 0x014c { 'x86' } 0x8664 { 'x64' } 0xaa64 { 'arm64' } default { '0x{0:X}' -f $machine } }
    } catch { 'ERR' }
}
Write-Host ("System32 regsvr32: {0}" -f (Get-PEArch 'C:\Windows\System32\regsvr32.exe'))
Write-Host ("SysWOW64 regsvr32: {0}" -f (Get-PEArch 'C:\Windows\SysWOW64\regsvr32.exe'))
Write-Host "=== find other regsvr32 copies ==="
Get-ChildItem 'C:\Windows' -Recurse -Filter 'regsvr32.exe' -Depth 2 -EA SilentlyContinue | Select-Object -ExpandProperty FullName
Write-Host "=== system dirs ==="
Get-ChildItem 'C:\Windows' -Directory -EA SilentlyContinue | Where-Object { $_.Name -match 'Sys|Arm' } | Select-Object -ExpandProperty Name
