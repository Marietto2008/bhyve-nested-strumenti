# prova-wsl-vhd.ps1 -- Claude 03/11/2026. FreeBSD come distro di sistema di WSL dal VHD indicato (in C:\claude\wsl-fbsd),
# virtio attivo, radice sulla partizione 4. Uso: prova-wsl-vhd.ps1 -Vhd fbsd152-wsl-ro3b [-Extra "networkingMode=none;guiApplications=false"]
# Le righe di -Extra si separano con ';' (con -File, schtasks consegna un'unica stringa e non un array).
param([string]$Vhd, [string[]]$Extra = @(), [switch]$Interattivo, [string]$ComandoFile = "", [string]$Url = "", [string]$Comando2File = "", [int]$BootTimeout = 180000, [string]$Utente = "", [string]$Ridimensiona = "", [string]$Riga = "console=comconsole rootdev=disk0p4:", [switch]$Verboso)
$Extra = @($Extra | ForEach-Object { $_ -split ';' } | Where-Object { $_ -ne '' })
if ($Verboso) { $Riga += " boot_verbose=YES" }   # -Verboso: avvio del kernel con tutti i messaggi
& C:\claude\prova-wsl-fbsd.ps1 -SystemDistro "C:\\claude\\wsl-fbsd\\$Vhd.vhd" -Riga $Riga -Extra $Extra -Interattivo:$Interattivo -ComandoFile $ComandoFile -Url $Url -Comando2File $Comando2File -BootTimeout $BootTimeout -Utente $Utente -Ridimensiona $Ridimensiona
