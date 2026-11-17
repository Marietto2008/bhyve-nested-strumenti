# avvio-windows.ps1 -- claude 17/11/2026: evento 41, tipo di avvio (27) e hive riorganizzati (KG15) dell'avvio in corso
# 17/11 sera: niente WMI (Get-CimInstance resta appeso con Windows occupata): ora d'avvio dall'ultimo Kernel-General 12
$b = (Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-General'; Id=12} -MaxEvents 1).TimeCreated.AddMinutes(-5)
$e = Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=$b} -ErrorAction SilentlyContinue
$k41 = ($e | Where-Object { $_.Id -eq 41 -and $_.ProviderName -eq 'Microsoft-Windows-Kernel-Power' } | Measure-Object).Count
$kb = ($e | Where-Object { $_.Id -eq 27 -and $_.ProviderName -eq 'Microsoft-Windows-Kernel-Boot' } | Select-Object -First 1).Message
if ($kb -match '(0x[0-9a-fA-F]+)') { $kb = $matches[1] } else { $kb = '?' }
$h = ($e | Where-Object { $_.Id -eq 15 -and $_.ProviderName -eq 'Microsoft-Windows-Kernel-General' } | ForEach-Object { if ($_.Message -match 'hive (\S+)') { ($matches[1] -split '\\')[-1] } }) -join ','
if (-not $h) { $h = 'nessuno' }
'k41=' + $k41 + ' kb27=' + $kb + ' kg15=' + $h
