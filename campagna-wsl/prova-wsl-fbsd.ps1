# prova-wsl-fbsd.ps1 -- Claude 03/11/2026. PRIMO avvio di FreeBSD DA WSL (ADR-002): .wslconfig con wsl2.uefiKernel,
# kernel = loader.efi, distro di sistema = il VHD di FreeBSD (collegato via SCSI alla creazione della VM, quindi disk0
# per il loader), console di debug. Atteso: FreeBSD che si avvia nella console di WSL, poi il TIMEOUT del servizio
# (nessun init risponde ancora al protocollo di WSL). Alla fine .wslconfig torna com'era (assente): Debian riparte.
param([string[]]$Extra = @(),   # righe in piu' per [wsl2], es. "virtio=false" (controprova del blocco su virtio_pci)
      [string]$SystemDistro = "C:\\claude\\wsl-fbsd\\fbsd152-wsl.vhd",   # 03/11: anche un disco di AVVIO di prova
      [string]$Riga = "console=comconsole rootdev=disk0p4:",
      [string[]]$Comando = @("uname", "-a"),   # 03/11 (I2): eseguito con wsl.exe -e; l'uscita dice chi ha risposto
      [string]$Distro = "FreeBSD",             # 03/11 (I2): la distro FreeBSD, registrata con --import-in-place
      [string]$DistroVhd = "C:\claude\wsl-fbsd\distro\FreeBSD.vhd",
      [switch]$Interattivo,                    # 03/11: alla fine la shell di FreeBSD in questa finestra (exit per uscire)
      [string]$ComandoFile = "",               # 03/11: script sh (senza virgolette doppie) eseguito con sh -c
      [string]$Url = "",                       # 03/11: dopo il comando, curl.exe da Windows (inoltro di localhost)
      [string]$Comando2File = "",              # 03/11: dopo wsl --terminate, un secondo script; poi wsl -u root -e id
      [int]$BootTimeout = 180000,              # 03/11 (punto 3): kernelBootTimeout in ms; 0 = predefinito di WSL
      [string]$Utente = "",                    # 03/11: utente del primo comando (wsl -u); vuoto = predefinito
      [string]$Ridimensiona = "")              # 03/11: prima dei comandi, wsl --manage <distro> --resize <dimensione>
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Claude: primo avvio di FreeBSD da WSL (wsl2.uefiKernel)"
try { $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(150, 5000) } catch { }
Start-Transcript -Path C:\claude\prova-wsl-fbsd.log -Force | Out-Null
function Passo($t) { Write-Host ""; Write-Host "[claude] $(Get-Date -Format HH:mm:ss) $t" -ForegroundColor Cyan }
$cfg = "$env:USERPROFILE\.wslconfig"
$conf = @"
[wsl2]
kernel=C:\\claude\\wsl-fbsd\\vmbfs\\loader.efi
uefiKernel=true
systemDistro=$SystemDistro
kernelCommandLine=$Riga
debugConsole=true
debugConsoleLogFile=C:\\claude\\wsl-fbsd\\console-wsl.txt
"@
if ($BootTimeout -gt 0) { $conf += "`r`nkernelBootTimeout=$BootTimeout" }
try {
    if (Test-Path $cfg) { throw ".wslconfig esiste gia': non lo tocco" }
    if (-not (Test-Path ($SystemDistro -replace "\\\\", "\"))) { throw "manca $SystemDistro" }
    if (Test-Path C:\claude\wsl-fbsd\console-wsl.txt) { Remove-Item C:\claude\wsl-fbsd\console-wsl.txt }
    Passo "1. .wslconfig per FreeBSD"
    Set-Content -Path $cfg -Value ($conf + "`r`n" + ($Extra -join "`r`n")) -Encoding ascii; Get-Content $cfg | Out-Host
    Passo "2. wsl --shutdown, poi wsl.exe -d $Distro (la VM parte con FreeBSD; si apre la console di debug)"
    $vecchio = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & wsl.exe --shutdown 2>&1 | Out-Null
    $t0 = Get-Date
    $registrate = @(& wsl.exe -l -q 2>&1 | ForEach-Object { ("$_" -replace "`0", "").Trim() })
    if ($registrate -notcontains $Distro) {
        Passo "2b. la distro $Distro non e' registrata: wsl --import-in-place $Distro $DistroVhd"
        & wsl.exe --import-in-place $Distro $DistroVhd 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
        Write-Host "[claude] import-in-place: codice $LASTEXITCODE"
    }
    if ($ComandoFile) { $Comando = @("sh", "-c", ((Get-Content $ComandoFile) -join "; ")) }
    Write-Host "[claude] comando: wsl.exe -d $Distro -e $($Comando -join ' ')"
    if ($Ridimensiona) {
        Passo "wsl --manage $Distro --resize $Ridimensiona"
        & wsl.exe --manage $Distro --resize $Ridimensiona 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
        Write-Host "[claude] resize: codice $LASTEXITCODE"
        Get-Item $DistroVhd | ForEach-Object { Write-Host ("[claude] {0}: {1:N1} GB" -f $_.Name, ($_.Length / 1GB)) }
    }
    $u = @(); if ($Utente) { $u = @("-u", $Utente) }
    & wsl.exe -d $Distro @u -e $Comando 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    $rc = $LASTEXITCODE
    if ($Url) {
        Write-Host "[claude] da Windows: curl.exe --http0.9 $Url"
        & curl.exe -s -S --http0.9 -m 15 $Url 2>&1 | ForEach-Object { "$_" } | Out-Host
        Write-Host "[claude] curl.exe: codice $LASTEXITCODE"
    }
    if ($Comando2File) {
        Write-Host "[claude] wsl --terminate $Distro (l'utente predefinito si decide all'avvio dell'istanza)"
        & wsl.exe --terminate $Distro 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
        $c2 = (Get-Content $Comando2File) -join "; "
        Write-Host "[claude] comando 2: wsl.exe -d $Distro -e sh -c $c2"
        & wsl.exe -d $Distro -e sh -c $c2 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
        Write-Host "[claude] wsl.exe -d $Distro -u root -e id"
        & wsl.exe -d $Distro -u root -e id 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    }
    Write-Host "[claude] wsl -l -v:"; & wsl.exe -l -v 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    if ($Interattivo) {
        Passo "shell interattiva: wsl.exe -d $Distro (exit per uscire)"
        & wsl.exe -d $Distro
        Write-Host "[claude] shell interattiva chiusa, codice $LASTEXITCODE"
    }
    $ErrorActionPreference = $vecchio
    Passo ("wsl.exe uscito con codice {0} dopo {1:N0} s" -f $rc, ((Get-Date) - $t0).TotalSeconds)
    Write-Host "ESITO: FATTO (vedi la console di debug di WSL)" -ForegroundColor Green
}
catch { Write-Host ""; Write-Host "ESITO: FERMATO - $($_.Exception.Message)" -ForegroundColor Red }
finally {
    Passo "3. ripristino: wsl --shutdown e .wslconfig tolto (copia in C:\claude\wslconfig-fbsd.ini)"
    $ErrorActionPreference = "Continue"
    & wsl.exe --shutdown 2>&1 | Out-Null
    if ((Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match "uefiKernel=true")) { Move-Item $cfg C:\claude\wslconfig-fbsd.ini -Force }
    Stop-Transcript | Out-Null; Write-Host "Premi un tasto per chiudere." -ForegroundColor Yellow; [void][Console]::ReadKey($true)
}
