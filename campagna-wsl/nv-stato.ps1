Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VEN_10DE' -or $_.Class -eq 'MEDIA' -or $_.Class -eq 'AudioEndpoint' } | ForEach-Object {
  $pc = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue).Data
  "{0,-6} pb={1,-3} {2,-14} {3}" -f $_.Status, $pc, $_.Class, $_.FriendlyName }
