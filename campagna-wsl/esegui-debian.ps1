# esegui-debian.ps1 -- Claude 04/11/2026. Esegue uno script sh in Debian (kernel Linux, niente .wslconfig) come root,
# nella sessione dell'utente (WSL non si avvia da ssh: "Accesso negato"). Log in C:\claude\esegui-debian.log.
param([string]$File = "C:\claude\debian.sh")
$Host.UI.RawUI.WindowTitle = "Claude: comando in Debian"
Start-Transcript -Path C:\claude\esegui-debian.log -Force | Out-Null
try {
    if (Test-Path "$env:USERPROFILE\.wslconfig") { throw ".wslconfig presente: non e' il kernel Linux" }
    $c = (Get-Content $File) -join "`n"
    & wsl.exe -d Debian -u root -e sh -c $c 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    Write-Host "ESITO: FATTO"
} catch { Write-Host "ESITO: FERMATO - $($_.Exception.Message)" }
finally { Stop-Transcript | Out-Null }
