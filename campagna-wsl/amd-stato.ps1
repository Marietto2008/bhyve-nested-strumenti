Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VEN_1002' } | ForEach-Object {
  "{0,-8} {1,-8} {2} | {3}" -f $_.Status, $_.Class, $_.FriendlyName, $_.InstanceId }
