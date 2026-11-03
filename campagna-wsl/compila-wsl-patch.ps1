# compila-wsl-patch.ps1 -- Claude 03/11/2026. Applica a C:\claude\src\WSL (b6fea0ff) la patch wsl2.uefiKernel
# (ramo wsf/freebsd dell'host, commit 1af82b66) e ricompila in Debug. L'albero risultante deve avere lo stesso hash
# di quello sull'host (lo sha del commit cambia con la data, l'albero no).
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Claude: WSL + wsl2.uefiKernel (avvio UEFI di FreeBSD), compilazione"
try { $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(160, 9000) } catch { }
Start-Transcript -Path C:\claude\compila-wsl-patch.log -Force | Out-Null
function Passo($t) { Write-Host ""; Write-Host "[claude] $(Get-Date -Format HH:mm:ss) $t" -ForegroundColor Cyan }
function Nativo { param([string]$exe, [string[]]$argomenti)
    $vecchio = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $exe @argomenti 2>&1 | ForEach-Object { "$_" } | Out-Host; $rc = $LASTEXITCODE
    $ErrorActionPreference = $vecchio
    if ($rc -ne 0) { throw "$exe $($argomenti -join ' '): codice $rc" } }
$cm = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\cmake.exe"
$t0 = Get-Date
try {
    Set-Location C:\claude\src\WSL
    $h = git rev-parse HEAD; Passo "sorgente: HEAD $h"
    if ($h -eq "b6fea0ff51c99f126760d3eaa86b71fdb6d2bdfa") {
        Passo "1. applico la patch (git am)"
        Nativo git @("-c", "user.name=Claude Opus 5.5", "-c", "user.email=noreply@anthropic.com", "am", "C:\claude\0001-wsl2.uefiKernel.patch")
    }
    $t = git rev-parse "HEAD^{tree}"; Write-Host "albero $t"
    if ($t -ne "21fd501b1c09e3bc425f18339c8e2e6c9dc2daa7") { throw "albero diverso da quello dell'host (21fd501b1c09e3bc425f18339c8e2e6c9dc2daa7)" }
    git log --oneline -2 | Out-Host
    Passo "2. compilazione (cmake --build . -- /m), Debug"
    $t1 = Get-Date
    Nativo $cm @("--build", ".", "--", "/m")
    Passo ("compilazione fatta in {0:N1} min" -f ((Get-Date) - $t1).TotalMinutes)
    Get-Item C:\claude\src\WSL\bin\x64\Debug\wsl.msi, C:\claude\src\WSL\bin\x64\Debug\wslservice.exe | ForEach-Object { "{0}  {1:N1} MB  {2}" -f $_.FullName, ($_.Length / 1MB), $_.LastWriteTime } | Out-Host
    Write-Host "ESITO: OK" -ForegroundColor Green
}
catch { Write-Host ""; Write-Host "ESITO: FERMATO - $($_.Exception.Message)" -ForegroundColor Red }
finally { Passo ("totale {0:N1} min" -f ((Get-Date) - $t0).TotalMinutes); Stop-Transcript | Out-Null; Write-Host "Premi un tasto per chiudere." -ForegroundColor Yellow; [void][Console]::ReadKey($true) }
