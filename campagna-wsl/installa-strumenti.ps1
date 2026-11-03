# installa-strumenti.ps1 -- Claude 03/11/2026. Strumenti per compilare WSL (microsoft/WSL b6fea0ff, ramo wsf/freebsd):
# modalita' sviluppatore, clone di WSL in C:\claude\src\WSL, CMake (winget), Visual Studio 2022 aggiornato e con i
# componenti del .vsconfig di quel commit. Il programma d'installazione di VS gira --passive: le barre si vedono.
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Claude: strumenti per compilare WSL"
Start-Transcript -Path C:\claude\installa-strumenti.log -Force | Out-Null
function Passo($t) { Write-Host ""; Write-Host "[claude] $(Get-Date -Format HH:mm:ss) $t" -ForegroundColor Cyan }
# i programmi esterni (git, winget) scrivono l'avanzamento su stderr: in PowerShell 5.1, con Stop e 2>&1, la prima
# riga diventava un errore fatale (03/11, clone interrotto). Si giudicano dal codice di uscita.
function Nativo { param([string]$exe, [string[]]$argomenti, [int[]]$ok = @(0))
    $vecchio = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $exe @argomenti 2>&1 | ForEach-Object { "$_" } | Out-Host; $rc = $LASTEXITCODE
    $ErrorActionPreference = $vecchio
    if ($rc -notin $ok) { throw "$exe $($argomenti -join ' '): codice $rc" } }
function Libero { "{0:N1} GB liberi su C:" -f ((Get-Volume -DriveLetter C).SizeRemaining / 1GB) | Out-Host }
$vsi = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$vsp = "C:\Program Files\Microsoft Visual Studio\2022\Community"
try {
    Libero
    Passo "1. modalita' sviluppatore"
    New-Item -Force -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name AllowDevelopmentWithoutDevLicense -Type DWord -Value 1
    Write-Host "AllowDevelopmentWithoutDevLicense = $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock').AllowDevelopmentWithoutDevLicense)"

    Passo "2. clone di WSL in C:\claude\src\WSL (commit b6fea0ff, remoto balajes = fork FreeBSD)"
    New-Item -ItemType Directory -Force C:\claude\src | Out-Null
    if (-not (Test-Path C:\claude\src\WSL\.git)) { Nativo git @("clone", "https://github.com/microsoft/WSL.git", "C:\claude\src\WSL") }
    Nativo git @("-C", "C:\claude\src\WSL", "checkout", "-B", "wsf/freebsd", "b6fea0ff51c99f126760d3eaa86b71fdb6d2bdfa")
    Nativo git @("-C", "C:\claude\src\WSL", "reset", "--hard", "b6fea0ff51c99f126760d3eaa86b71fdb6d2bdfa")
    if (-not (git -C C:\claude\src\WSL remote | Select-String -SimpleMatch balajes)) { Nativo git @("-C", "C:\claude\src\WSL", "remote", "add", "balajes", "https://github.com/BalajeS/WSL-For-FreeBSD.git") }
    $h = git -C C:\claude\src\WSL rev-parse HEAD; Write-Host "HEAD $h"
    $sporchi = @(git -C C:\claude\src\WSL status --short).Count; Write-Host "file diversi dal commit: $sporchi"
    if ($h -ne "b6fea0ff51c99f126760d3eaa86b71fdb6d2bdfa" -or $sporchi -ne 0) { throw "clone non conforme: $h, $sporchi file diversi" }
    Libero

    Passo "3. CMake (winget, Kitware.CMake)"
    Nativo winget @("install", "--id", "Kitware.CMake", "-e", "--silent", "--accept-source-agreements", "--accept-package-agreements") @(0, -1978335189)
    # winget installa CMake come pacchetto PORTATILE nel profilo (alias in WinGet\Links), non in Program Files
    $cm = @("$env:LOCALAPPDATA\Microsoft\WinGet\Links\cmake.exe", "C:\Program Files\CMake\bin\cmake.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($cm) { Write-Host "cmake: $cm"; & $cm --version | Select-Object -First 1 | Out-Host } else { throw "CMake non trovato" }

    Passo "4. aggiornamento di Visual Studio 2022 (finestra del programma d'installazione)"
    & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -format value -property catalog_productDisplayVersion | ForEach-Object { "prima: $_" } | Out-Host
    $p = Start-Process -FilePath $vsi -ArgumentList @("update", "--installPath", "`"$vsp`"", "--passive", "--norestart") -Wait -PassThru
    Write-Host "update: codice $($p.ExitCode)"; if ($p.ExitCode -notin 0, 3010) { throw "aggiornamento di VS fallito: $($p.ExitCode)" }
    Libero

    Passo "5. componenti del .vsconfig di WSL"
    $p = Start-Process -FilePath $vsi -ArgumentList @("modify", "--installPath", "`"$vsp`"", "--config", "`"C:\claude\src\WSL\.vsconfig`"", "--passive", "--norestart") -Wait -PassThru
    Write-Host "modify: codice $($p.ExitCode)"; if ($p.ExitCode -notin 0, 3010) { throw "aggiunta dei componenti fallita: $($p.ExitCode)" }
    & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -format value -property catalog_productDisplayVersion | ForEach-Object { "dopo: $_" } | Out-Host
    Libero
    Passo "FATTO"; Write-Host "ESITO: OK" -ForegroundColor Green
}
catch { Write-Host ""; Write-Host "ESITO: FERMATO - $($_.Exception.Message)" -ForegroundColor Red }
finally { Stop-Transcript | Out-Null; Write-Host ""; Write-Host "Premi un tasto per chiudere." -ForegroundColor Yellow; [void][Console]::ReadKey($true) }
