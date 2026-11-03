# prova-virtio-dbg.ps1 -- Claude 03/11/2026. Kernel di prova CLAUDE-WSL (virtio_pci strumentato, DDB) dal disco di avvio
# avvio-dbg1.vhdx (LUN 1), radice dal disco principale, console virtio hvc0 come in WSL, avvio verboso.
& C:\claude\wsl-fbsd\hcs-fbsd-dal-vivo.ps1 -Avvio VmbFs -ConsoleVirtio -Disco2 C:\claude\wsl-fbsd\avvio-dbg1.vhdx -Opzioni "console=comconsole rootdev=disk1p1: boot_verbose=YES"
