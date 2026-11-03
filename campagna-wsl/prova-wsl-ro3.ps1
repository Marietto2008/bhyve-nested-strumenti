# prova-wsl-ro3.ps1 -- Claude 03/11/2026. FreeBSD 15.2 + correzioni vPCI/MSI, radice in sola lettura, come distro di
# sistema di WSL, con virtio ATTIVO (la configurazione predefinita di WSL). Atteso: multiutente, poi timeout del servizio.
& C:\claude\prova-wsl-fbsd.ps1 -SystemDistro "C:\\claude\\wsl-fbsd\\fbsd152-wsl-ro3.vhd" -Riga "console=comconsole rootdev=disk0p4:"
