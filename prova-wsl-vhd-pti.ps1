# prova-wsl-vhd-pti.ps1 -- Claude 10/11/2026, confronto KVM <-> bhyve. Come prova-wsl-vhd.ps1, ma con il PTI di
# FreeBSD acceso a forza (vm.pmap.pti=1 sulla riga del loader, che la passa al kernel come variabile d'ambiente).
# Perche': sotto il nostro bhyve l'L2 non riceve RDCL_NO in IA32_ARCH_CAPABILITIES e accende il PTI da solo;
# sotto KVM lo riceve e il PTI resta spento. Cosi' i due L0 vedono lo STESSO FreeBSD.
# L'ULTIMO argomento della riga arriva al loader con un carattere spurio in coda (10/11: vm.pmap.pti="1?", scartato
# dal kernel): vm.pmap.pti sta in mezzo e in fondo c'e' claude_coda=1, che non legge nessuno.
param([string]$Vhd, [string]$ComandoFile = "", [int]$BootTimeout = 180000, [string]$Utente = "")
& C:\claude\prova-wsl-vhd.ps1 -Vhd $Vhd -ComandoFile $ComandoFile -BootTimeout $BootTimeout -Utente $Utente -Riga "console=comconsole rootdev=disk0p4: vm.pmap.pti=1 claude_coda=1"
