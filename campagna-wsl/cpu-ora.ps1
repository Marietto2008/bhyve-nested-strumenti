# cpu-ora.ps1 -- Claude 04/11/2026: chi consuma CPU ADESSO in Windows (differenza su 5 s), e il carico totale.
$a = @{}; Get-Process | ForEach-Object { $a[$_.Id] = $_.CPU }
Start-Sleep -Seconds 5
$n = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
Get-Process | ForEach-Object { if ($a.ContainsKey($_.Id) -and $_.CPU) { [pscustomobject]@{ Nome = $_.Name; Id = $_.Id; PercCPU = [math]::Round(($_.CPU - $a[$_.Id]) / 5 * 100, 1) } } } |
  Sort-Object PercCPU -Descending | Select-Object -First 10 | Format-Table -AutoSize | Out-String -Width 120
"totale: " + [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue, 1) + "% di $n CPU logiche"
"wsl: " + ((Get-Process wsl, vmmem, vmmemWSL -ErrorAction SilentlyContinue | ForEach-Object Name) -join ', ')
