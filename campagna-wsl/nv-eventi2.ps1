Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddMinutes(-10)} -ErrorAction SilentlyContinue |
  Where-Object { $_.ProviderName -match 'nvlddmkm|Display|Kernel-PnP|WHEA|pci' -or $_.Message -match 'NVIDIA|VEN_10DE' } | Sort-Object TimeCreated |
  ForEach-Object { $m = ($_.Message -replace '\s+', ' '); if ($m.Length -gt 300) { $m = $m.Substring(0,300) }
    "{0:HH:mm:ss} {1} id={2} {3}: {4}" -f $_.TimeCreated, $_.ProviderName, $_.Id, $_.LevelDisplayName, $m }
