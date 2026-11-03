Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue | ForEach-Object {
    $p = Get-ItemProperty $_.PSPath
    '{0} nome={1} stato={2} versione={3} base={4} vhd={5}' -f $_.PSChildName, $p.DistributionName, $p.State, $p.Version, $p.BasePath, $p.VhdFileName
}
'servizio: ' + (Get-Service WSLService).Status
'processi: ' + ((Get-Process wsl, vmmemWSL -ErrorAction SilentlyContinue | ForEach-Object { $_.Name + '/' + $_.Id }) -join ' ')
'.wslconfig presente: ' + (Test-Path (Join-Path $env:USERPROFILE .wslconfig))
