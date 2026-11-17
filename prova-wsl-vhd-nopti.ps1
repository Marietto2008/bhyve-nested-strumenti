# prova-wsl-vhd-nopti.ps1 -- Claude 10/11/2026, confronto KVM <-> bhyve. Come prova-wsl-vhd-pti.ps1 ma con il PTI di
# FreeBSD SPENTO a forza (vm.pmap.pti=0): sotto il nostro bhyve l'L2 lo accende da solo (manca RDCL_NO), sotto KVM no.
# Se sotto bhyve il panic sparisce col PTI spento, il PTI e' condizione necessaria (pista A di Fable 018: CR3).
# vm.pmap.pti NON in fondo alla riga: l'ultimo argomento arriva al loader con un carattere spurio in coda.
param([string]$Vhd, [string]$ComandoFile = "", [int]$BootTimeout = 180000, [string]$Utente = "")
& C:\claude\prova-wsl-vhd.ps1 -Vhd $Vhd -ComandoFile $ComandoFile -BootTimeout $BootTimeout -Utente $Utente -Riga "console=comconsole rootdev=disk0p4: vm.pmap.pti=0 claude_coda=1"
