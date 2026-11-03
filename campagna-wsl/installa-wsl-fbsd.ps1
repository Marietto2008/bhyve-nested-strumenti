# installa-wsl-fbsd.ps1 -- Claude 03/11/2026. Installa nel clone il WSL compilato con wsl2.uefiKernel (ADR-002):
# annota lo stato di prima (per tornare indietro: wsl --update), msiexec visibile, verifica che il servizio sia il
# nostro (sha di wslservice.exe), poi prova di NON regressione: Debian si avvia con il WSL nuovo, senza .wslconfig.
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Claude: installazione del WSL compilato (wsl2.uefiKernel)"
Start-Transcript -Path C:\claude\installa-wsl-fbsd.log -Force | Out-Null
function Passo($t) { Write-Host ""; Write-Host "[claude] $(Get-Date -Format HH:mm:ss) $t" -ForegroundColor Cyan }
function Nativo { param([string]$exe, [string[]]$argomenti, [int[]]$ok = @(0))
    $vecchio = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $exe @argomenti 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host; $rc = $LASTEXITCODE
    $ErrorActionPreference = $vecchio
    if ($rc -notin $ok) { throw "$exe $($argomenti -join ' '): codice $rc" } }
$msi = "C:\claude\src\WSL\bin\x64\Debug\wsl.msi"
$svcNuovo = (Get-FileHash C:\claude\src\WSL\bin\x64\Debug\wslservice.exe).Hash
try {
    Passo "1. stato di PRIMA (per tornare indietro: wsl --update)"
    Nativo wsl.exe @("--version")
    Nativo wsl.exe @("--list", "--verbose")
    $cfg = "$env:USERPROFILE\.wslconfig"
    if (Test-Path $cfg) { Copy-Item $cfg "$cfg.prima-wsl-fbsd" -Force; Write-Host ".wslconfig esistente salvato in $cfg.prima-wsl-fbsd"; Get-Content $cfg | Out-Host }
    else { Write-Host ".wslconfig: assente" }
    Get-Package -Name "*Subsystem for Linux*" -ErrorAction SilentlyContinue | Format-Table Name, Version, ProviderName -AutoSize | Out-Host

    Passo "2. wsl --shutdown"
    Nativo wsl.exe @("--shutdown")

    Passo "3. installazione di $msi (sha servizio atteso $svcNuovo)"
    $p = Start-Process -Wait -PassThru msiexec.exe -ArgumentList @("/i", "`"$msi`"", "/qb", "/norestart", "/l*v", "`"C:\claude\wsl-msi.log`"")
    Write-Host "msiexec: codice $($p.ExitCode)"
    if ($p.ExitCode -notin 0, 3010) { throw "installazione fallita: $($p.ExitCode) (registro C:\claude\wsl-msi.log)" }

    Passo "4. il servizio installato e' il nostro?"
    $svc = Get-CimInstance Win32_Service -Filter "Name='WSLService'"
    $exe = ($svc.PathName -replace '^"([^"]+)".*$', '$1')
    $sha = (Get-FileHash $exe).Hash
    Write-Host "WSLService: $exe, stato $($svc.State), sha $sha"
    if ($sha -ne $svcNuovo) { throw "wslservice.exe installato NON e' quello compilato" }
    Nativo wsl.exe @("--version")

    Passo "5. non regressione: Debian con il WSL nuovo, senza .wslconfig"
    if (Test-Path $cfg) { Rename-Item $cfg "$cfg.sospeso"; $sospeso = $true }
    try { Nativo wsl.exe @("-d", "Debian", "--", "uname", "-a") } finally { if ($sospeso) { Rename-Item "$cfg.sospeso" $cfg } }
    Nativo wsl.exe @("--shutdown")
    Write-Host "ESITO: OK" -ForegroundColor Green
}
catch { Write-Host ""; Write-Host "ESITO: FERMATO - $($_.Exception.Message)" -ForegroundColor Red }
finally { Stop-Transcript | Out-Null; Write-Host "Premi un tasto per chiudere." -ForegroundColor Yellow; [void][Console]::ReadKey($true) }
