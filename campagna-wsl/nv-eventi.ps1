Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3} -MaxEvents 25 -ErrorAction SilentlyContinue |
  ForEach-Object { $m = ($_.Message -replace '\s+', ' '); if ($m.Length -gt 230) { $m = $m.Substring(0,230) }
    "{0:dd/MM HH:mm:ss} {1} id={2}: {3}" -f $_.TimeCreated, $_.ProviderName, $_.Id, $m }
