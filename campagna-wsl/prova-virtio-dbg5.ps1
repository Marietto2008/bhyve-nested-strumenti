# prova-virtio-dbg5.ps1 -- Claude 03/11/2026. Come prova-virtio-dbg.ps1 ma col kernel CORRETTO (vmbus_pcib: decodifica
# spenta attorno alle scritture delle BAR, 3fec12614): con la console virtio di WSL lo stato deve leggere 0x00.
& C:\claude\wsl-fbsd\hcs-fbsd-dal-vivo.ps1 -Avvio VmbFs -ConsoleVirtio -Disco2 C:\claude\wsl-fbsd\avvio-dbg5.vhdx -Opzioni "console=comconsole rootdev=disk1p1: boot_verbose=YES"
