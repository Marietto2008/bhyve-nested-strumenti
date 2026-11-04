# linux-wslg.ps1 -- Claude 04/11/2026. CONTROPROVA: WSLg vero (Debian, kernel Linux di WSL, distro di sistema di
# Microsoft) nella stessa VM Windows senza GPU. Se anche qui le finestre RAIL non si vedono, il problema non e' il
# porting FreeBSD. Log in C:\claude\linux-wslg.log; le app restano aperte 10 minuti.
$Host.UI.RawUI.WindowTitle = "Claude: controprova WSLg con Linux"
Start-Transcript -Path C:\claude\linux-wslg.log -Force | Out-Null
function Passo($t) { Write-Host ""; Write-Host "[claude] $(Get-Date -Format HH:mm:ss) $t" -ForegroundColor Cyan }
try {
    if (Test-Path "$env:USERPROFILE\.wslconfig") { throw ".wslconfig presente: non sarebbe il kernel Linux" }
    $ErrorActionPreference = "Continue"
    Passo "1. wsl --shutdown e versione"
    & wsl.exe --shutdown 2>&1 | Out-Null
    & wsl.exe --version 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Select-Object -First 3 | Out-Host
    Passo "2. x11-apps in Debian (root)"
    & wsl.exe -d Debian -u root -e sh -c "uname -r; apt-get update -qq >/dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq x11-apps >/dev/null 2>&1; command -v xclock xeyes" 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    Passo "3. WSLg: DISPLAY, WAYLAND_DISPLAY e /mnt/wslg"
    & wsl.exe -d Debian -e sh -c "echo DISPLAY=`$DISPLAY WAYLAND_DISPLAY=`$WAYLAND_DISPLAY; ls /mnt/wslg | head" 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    Passo "4. xclock e xeyes con WSLg (restano aperti 10 minuti)"
    $a = Start-Process wsl.exe -ArgumentList @("-d", "Debian", "-e", "xclock") -PassThru -WindowStyle Minimized
    $b = Start-Process wsl.exe -ArgumentList @("-d", "Debian", "-e", "xeyes") -PassThru -WindowStyle Minimized
    Start-Sleep 600
    Passo "5. chiusura"
    foreach ($p in $a, $b) { if (-not $p.HasExited) { Stop-Process $p -Force } }
    & wsl.exe -d Debian -e sh -c "tail -20 /mnt/wslg/weston.log" 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-Host
    Write-Host "ESITO: FATTO"
} catch { Write-Host "ESITO: FERMATO - $($_.Exception.Message)" }
finally { Stop-Transcript | Out-Null }
