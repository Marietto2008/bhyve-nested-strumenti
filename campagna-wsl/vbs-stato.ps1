$dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard
"VBS stato={0} servizi configurati=[{1}] in esecuzione=[{2}] proprieta' richieste=[{3}] disponibili=[{4}]" -f $dg.VirtualizationBasedSecurityStatus, ($dg.SecurityServicesConfigured -join ','), ($dg.SecurityServicesRunning -join ','), ($dg.RequiredSecurityProperties -join ','), ($dg.AvailableSecurityProperties -join ',')
"--- registro DeviceGuard"
reg query HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard /s 2>$null | Select-String -Pattern 'Enable|Require|Locked|HVCI|Mandatory' | ForEach-Object { $_.Line.Trim() }
"--- criteri"
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard 2>$null | Select-String -Pattern 'REG_' | ForEach-Object { $_.Line.Trim() }
"--- eventi VBS/hypervisor di questo avvio"
Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddMinutes(-15)} -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -match 'Hyper-V-Hypervisor|Kernel-Boot|DeviceGuard' } | ForEach-Object { $m = ($_.Message -replace '\s+', ' '); if ($m.Length -gt 200) { $m = $m.Substring(0,200) }; "{0:HH:mm:ss} {1} id={2}: {3}" -f $_.TimeCreated, $_.ProviderName, $_.Id, $m }
