# pulisci-wsl.ps1 -- Claude 03/11/2026. Dopo una prova appesa: chiude i wsl.exe, ferma il servizio WSL (spegne la
# VM), mette da parte un .wslconfig lasciato da una prova (solo se e' il nostro: uefiKernel=true) e toglie dal
# registro le registrazioni FreeBSD rimaste A META' (stato diverso da 1 = installata). Debian non si tocca.
Get-Process wsl -ErrorAction SilentlyContinue | Stop-Process -Force
# anche i client RDP di WSLg rimasti da una prova (03/11: tre msrdc aperti impedivano la connessione successiva?)
Get-Process msrdc -ErrorAction SilentlyContinue | Stop-Process -Force
Stop-Service WSLService -Force -WarningAction SilentlyContinue
$c = Join-Path $env:USERPROFILE .wslconfig
if ((Test-Path $c) -and ((Get-Content $c -Raw) -match 'uefiKernel=true')) {
    $d = 'C:\claude\wslconfig-rimasto-' + (Get-Date -Format HHmmss) + '.ini'; Move-Item $c $d -Force; "wslconfig messo da parte in $d"
}
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue | ForEach-Object {
    $p = Get-ItemProperty $_.PSPath
    if ($p.DistributionName -eq 'FreeBSD' -and $p.State -ne 1) { Remove-Item $_.PSPath -Recurse; "tolta la registrazione incompleta $($_.PSChildName) (stato $($p.State))" }
}
'servizio: ' + (Get-Service WSLService).Status
'processi: ' + ((Get-Process wsl, vmmemWSL, msrdc -ErrorAction SilentlyContinue | ForEach-Object { $_.Name + '/' + $_.Id }) -join ' ')
