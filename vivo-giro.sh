#!/bin/sh
# vivo-giro.sh <ora HH:MM:SS> <etichetta> [script.ps1 in C:\claude, di base vivo2.ps1] -- Claude 15/11/2026, prova (b): all'ora data lancia C:\claude\vivo2.ps1 nella
# Windows vm0:13 (thread di claude-lag con WCHAN, timer per CPU dentro FreeBSD-L2) e salva in dati-bhyve/vivo-<etichetta>.txt.
# Serve a vedere il thread appeso PRIMA che la pulizia di WSL del giro dopo chiuda la sessione.
set -u
P=/home/marietto/.config/claude-wsl2/password-windows
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-bhyve
O=$D/vivo-$2.txt
WIN=$(arp -an | awk '/00:a0:98:a1:73:65/ {gsub(/[()]/, "", $2); print $2; exit}'); WIN=${WIN:-IP-WINDOWS-A}
w() { timeout 90 sshpass -f $P ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o PreferredAuthentications=password \
	-o ConnectTimeout=20 marietto@$WIN "$1" 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r\0'; }
while [ "$(date +%H%M%S)" -lt "$(echo $1 | tr -d :)" ]; do sleep 5; done
echo "$(date +%T) ${3:-vivo2.ps1} su $WIN" >> $O
w 'del C:\claude\vivo.txt C:\claude\vivo-out.txt 2>nul & schtasks /create /tn ClaudeVivo /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\claude\'"${3:-vivo2.ps1}"'" /sc once /sd 01/01/2020 /st 00:00 /it /f >nul && schtasks /run /tn ClaudeVivo' >> $O
for i in $(seq 1 200); do r=$(w 'type C:\claude\vivo.txt'); echo "$r" | /usr/bin/grep -q '^fine' && break; sleep 5; done
echo "$r" >> $O
w 'schtasks /delete /tn ClaudeVivo /f' >/dev/null
echo "$(date +%T) fatto" >> $O
