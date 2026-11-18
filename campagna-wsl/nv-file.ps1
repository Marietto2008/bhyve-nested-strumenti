$files = @('C:\Windows\System32\nvidia-smi.exe','C:\Windows\System32\nvml.dll','C:\Program Files\NVIDIA Corporation\NVSMI\nvml.dll','C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe')
foreach ($f in $files) { if (Test-Path $f) { $v = (Get-Item $f).VersionInfo; "{0} prodotto={1} file={2} {3}" -f $f, $v.ProductVersion, $v.FileVersion, (Get-Item $f).LastWriteTime } else { "$f assente" } }
Get-ChildItem 'C:\Windows\System32\DriverStore\FileRepository' -Directory -Filter 'nv_dispi*' | ForEach-Object {
  $n = Join-Path $_.FullName 'nvml.dll'; $s = Join-Path $_.FullName 'nvidia-smi.exe'
  "{0}: nvml={1} smi={2}" -f $_.Name, (Test-Path $n), (Test-Path $s) }
(Get-PnpDeviceProperty -InstanceId 'PCI\VEN_10DE&DEV_1E04&SUBSYS_250319DA&REV_A1\3&11583659&0&40' -KeyName DEVPKEY_Device_DriverVersion).Data
Get-Service | Where-Object { $_.Name -match '^NV' } | Format-Table -AutoSize Name,Status,StartType | Out-String
