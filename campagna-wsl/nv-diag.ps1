$ids = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VEN_10DE.*11583659' }
foreach ($d in $ids) {
  $ps = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_Device_ProblemStatus -ErrorAction SilentlyContinue).Data
  $pc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue).Data
  "{0} | {1} | problema {2} | NTSTATUS 0x{3:X8}" -f $d.FriendlyName, $d.InstanceId, $pc, $ps
}
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-PnP'; StartTime=(Get-Date).AddHours(-1)} -ErrorAction SilentlyContinue |
  Where-Object { $_.Message -match 'VEN_10DE' } | Select-Object -First 8 | ForEach-Object { "{0} {1}: {2}" -f $_.TimeCreated, $_.Id, ($_.Message -replace '\s+', ' ') }
