$da = (Get-Date).AddHours(-2)
"--- dump"
Get-ChildItem C:\Windows\Minidump -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 3 | ForEach-Object { "{0} {1} {2}" -f $_.Name, $_.Length, $_.LastWriteTime }
if (Test-Path C:\Windows\MEMORY.DMP) { $m = Get-Item C:\Windows\MEMORY.DMP; "MEMORY.DMP {0} {1}" -f $m.Length, $m.LastWriteTime }
"--- sistema (critici/errori/avvisi)"
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3; StartTime=$da} -ErrorAction SilentlyContinue | Sort-Object TimeCreated |
  ForEach-Object { $m = ($_.Message -replace '\s+', ' '); if ($m.Length -gt 260) { $m = $m.Substring(0,260) }
    "{0:HH:mm:ss} {1} id={2}: {3}" -f $_.TimeCreated, $_.ProviderName, $_.Id, $m }
"--- applicazione (critici/errori)"
Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2; StartTime=$da} -ErrorAction SilentlyContinue | Sort-Object TimeCreated |
  ForEach-Object { $m = ($_.Message -replace '\s+', ' '); if ($m.Length -gt 300) { $m = $m.Substring(0,300) }
    "{0:HH:mm:ss} {1} id={2}: {3}" -f $_.TimeCreated, $_.ProviderName, $_.Id, $m }
