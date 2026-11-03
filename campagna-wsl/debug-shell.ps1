# debug-shell.ps1 -- Claude 03/11/2026. Apre la debug shell della VM di WSL (wsl --debug-shell, va lanciato ELEVATO).
$Host.UI.RawUI.WindowTitle = "Claude: debug shell della VM FreeBSD di WSL"
Write-Host "[claude] wsl --debug-shell (FreeBSD: getty su ttyV0.2 = porta virtio hvc2)" -ForegroundColor Cyan
& wsl.exe --debug-shell
Write-Host "[claude] debug shell chiusa, codice $LASTEXITCODE"; Start-Sleep 30
