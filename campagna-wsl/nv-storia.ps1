Get-PnpDevice | Where-Object { $_.InstanceId -match 'VEN_10DE' } | ForEach-Object {
  $svc = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_Service -ErrorAction SilentlyContinue).Data
  $inf = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction SilentlyContinue).Data
  $last = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_LastArrivalDate -ErrorAction SilentlyContinue).Data
  "{0,-8} {1,-45} {2} svc={3} inf={4} ultimo={5}" -f $_.Status, $_.FriendlyName, ($_.InstanceId -replace '.*\\',''), $svc, $inf, $last
}
