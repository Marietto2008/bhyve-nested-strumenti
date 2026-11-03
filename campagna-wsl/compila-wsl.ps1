# compila-wsl.ps1 -- Claude 03/11/2026. Compilazione di RIFERIMENTO di WSL (microsoft/WSL b6fea0ff, nessuna modifica,
# Debug) in C:\claude\src\WSL: prima di toccare il codice per FreeBSD si sa che il WSL di partenza si compila qui.
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Claude: compilazione di riferimento di WSL (b6fea0ff, Debug)"
try { $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(160, 9000) } catch { }
Start-Transcript -Path C:\claude\compila-wsl.log -Force | Out-Null
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
    $h = git rev-parse HEAD; $n = @(git status --short).Count
    Passo "sorgente: HEAD $h, file modificati $n"
    if ($h -ne "b6fea0ff51c99f126760d3eaa86b71fdb6d2bdfa" -or $n -ne 0) { throw "sorgente non conforme" }
    Passo "1. configurazione (cmake .)"
    Nativo $cm @(".")
    Passo ("configurazione fatta in {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds)
    Passo "2. compilazione (cmake --build . -- /m), Debug"
    $t1 = Get-Date
    Nativo $cm @("--build", ".", "--", "/m")
    Passo ("compilazione fatta in {0:N1} min" -f ((Get-Date) - $t1).TotalMinutes)
    Passo "3. prodotti"
    Get-ChildItem -Recurse -Include *.msi, wsl.exe, wslservice.exe -ErrorAction SilentlyContinue | Select-Object -First 10 | ForEach-Object { "{0}  {1:N1} MB" -f $_.FullName, ($_.Length / 1MB) } | Out-Host
    "{0:N1} GB liberi su C:" -f ((Get-Volume -DriveLetter C).SizeRemaining / 1GB) | Out-Host
    Write-Host "ESITO: OK" -ForegroundColor Green
}
catch { Write-Host ""; Write-Host "ESITO: FERMATO - $($_.Exception.Message)" -ForegroundColor Red }
finally { Passo ("totale {0:N1} min" -f ((Get-Date) - $t0).TotalMinutes); Stop-Transcript | Out-Null; Write-Host "Premi un tasto per chiudere." -ForegroundColor Yellow; [void][Console]::ReadKey($true) }
