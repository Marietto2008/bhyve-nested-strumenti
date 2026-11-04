# esegui-freebsd.ps1 -- Claude 04/11/2026. Esegue uno script sh in FreeBSD (con il .wslconfig di FreeBSD gia' attivo) come root,
# nella sessione dell'utente (WSL non si avvia da ssh: "Accesso negato"). Log in C:\claude\esegui-freebsd.log.
param([string]$File = "C:\claude\freebsd.sh")
$Host.UI.RawUI.WindowTitle = "Claude: comando in FreeBSD"
Start-Transcript -Path C:\claude\esegui-freebsd.log -Force | Out-Null
try {
    $c = (Get-Content $File) -join "`n"
    & wsl.exe -d FreeBSD -u root -e sh -c $c 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    Write-Host "ESITO: FATTO"
} catch { Write-Host "ESITO: FERMATO - $($_.Exception.Message)" }
finally { Stop-Transcript | Out-Null }
