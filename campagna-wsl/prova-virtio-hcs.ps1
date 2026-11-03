# prova-virtio-hcs.ps1 -- Claude 03/11/2026. Riproduce fuori da WSL il blocco su virtio_pci: console dal vivo, avvio
# VmbFs, console virtio hvc0 come in WSL, avvio verboso del kernel.
& C:\claude\wsl-fbsd\hcs-fbsd-dal-vivo.ps1 -Avvio VmbFs -ConsoleVirtio -Opzioni "console=comconsole rootdev=disk0p4: boot_verbose=YES"
