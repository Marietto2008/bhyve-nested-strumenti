# prova-wsl-vhd.ps1 -- Claude 03/11/2026. FreeBSD come distro di sistema di WSL dal VHD indicato (in C:\claude\wsl-fbsd),
# virtio attivo, radice sulla partizione 4. Uso: prova-wsl-vhd.ps1 -Vhd fbsd152-wsl-ro3b [-Extra "networkingMode=none;guiApplications=false"]
# Le righe di -Extra si separano con ';' (con -File, schtasks consegna un'unica stringa e non un array).
param([string]$Vhd, [string[]]$Extra = @(), [switch]$Interattivo)
$Extra = @($Extra | ForEach-Object { $_ -split ';' } | Where-Object { $_ -ne '' })
& C:\claude\prova-wsl-fbsd.ps1 -SystemDistro "C:\\claude\\wsl-fbsd\\$Vhd.vhd" -Riga "console=comconsole rootdev=disk0p4:" -Extra $Extra -Interattivo:$Interattivo
