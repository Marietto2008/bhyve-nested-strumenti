# misura-linux.ps1 -- Claude 03/11/2026. Riferimento Linux: gli stessi comandi di rete nella Debian col kernel Linux di
# WSL (nessun .wslconfig), nella stessa catena annidata della VM FreeBSD. Log in C:\claude\misura-linux.log.
param([string]$ComandoFile = "C:\claude\misura-linux.sh")
$Host.UI.RawUI.WindowTitle = "Claude: riferimento Linux (rete)"
Start-Transcript -Path C:\claude\misura-linux.log -Force | Out-Null
try {
    if (Test-Path "$env:USERPROFILE\.wslconfig") { throw ".wslconfig presente: non e' il kernel Linux" }
    $ErrorActionPreference = "Continue"
    & wsl.exe --shutdown 2>&1 | Out-Null
    $c = (Get-Content $ComandoFile) -join "; "
    Write-Host "[claude] wsl -d Debian -e sh -c $c"
    & wsl.exe -d Debian -e sh -c $c 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    Write-Host "ESITO: FATTO, codice $LASTEXITCODE"
} catch { Write-Host "ESITO: FERMATO - $($_.Exception.Message)" }
finally { & wsl.exe --shutdown 2>&1 | Out-Null; Stop-Transcript | Out-Null }
