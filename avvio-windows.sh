#!/bin/sh
# avvio-windows.sh -- claude 17/11/2026 (Fable 069 par. 4.4 e 071 par. 2): dal registro eventi di Windows, per l'avvio in
# corso: Kernel-Power 41 (il precedente fu brusco), Kernel-Boot 27 (tipo di avvio), Kernel-General 15 (hive
# riorganizzati: la manutenzione settimanale coincide con i guasti A del 10/11 e del 17/11). Stampa
#   k41=<n> kb27=<tipo> kg15=<hive,hive|nessuno>
# o niente se Windows non risponde in ~4 minuti.
PF=/home/marietto/.config/claude-wsl2/password-windows
i=0
while [ $i -lt 15 ]; do
	sshpass -f $PF scp -q -o StrictHostKeyChecking=no -o ConnectTimeout=8 /mnt/linuxulator2/vm/confronto-kvm-bhyve/strumenti/avvio-windows.ps1 marietto@IP-WINDOWS-A:C:/claude/avvio-windows.ps1 2>/dev/null
	r=$(sshpass -f $PF ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 marietto@IP-WINDOWS-A 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\claude\avvio-windows.ps1' 2>/dev/null | tr -d '\r' | tail -1)
	case "$r" in k41=*) echo "$r"; exit 0;; esac
	i=$((i + 1)); sleep 8
done
exit 1
