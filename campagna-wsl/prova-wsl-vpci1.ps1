# prova-wsl-vpci1.ps1 -- Claude 03/11/2026. Kernel di prova CLAUDE-WSL nella VM di WSL vera (console virtio + virtiofs):
# distro di sistema = il disco di AVVIO (niente radice: si ferma a mountroot, ma i dispositivi sono gia collegati).
& C:\claude\prova-wsl-fbsd.ps1 -SystemDistro "C:\\claude\\wsl-fbsd\\avvio-vpci1.vhd" -Riga "console=comconsole rootdev=disk0p1: boot_verbose=YES"
