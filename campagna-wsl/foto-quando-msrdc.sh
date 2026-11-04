#!/bin/sh
# foto-quando-msrdc.sh -- aspetta che l'init chieda a Windows di lanciare msrdc, poi fotografa lo schermo
D=/tmp/claude-1001/-mnt-linuxulator2-freebsd-radxa-src/5c397449-f584-4e61-9504-47b7fe6ab862/scratchpad
S="sshpass -f /home/marietto/.config/claude-wsl2/password-windows"; O="-o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o ConnectTimeout=20"
$S scp $O $D/cattura-schermo.ps1 'marietto@IP-WINDOWS-B:C:/claude/' 2>/dev/null
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 900 ]; do
	timeout 30 $S ssh $O marietto@IP-WINDOWS-B 'type C:\claude\prova-wsl-fbsd.log' 2>/dev/null | grep -q "${2:-wslg-desktop.sh}" && \
	timeout 30 $S ssh $O marietto@IP-WINDOWS-B 'tasklist /fi "imagename eq msrdc.exe"' 2>/dev/null | grep -qi msrdc && break
	sleep 10
done
echo "msrdc visto dopo $(( $(date +%s) - t0 )) s"; sleep ${1:-25}
timeout 60 $S ssh $O marietto@IP-WINDOWS-B 'schtasks /create /tn ClaudeFoto /tr "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\claude\riduci-e-fotografa.ps1" /sc once /sd 01/01/2020 /st 00:00 /it /f >nul && schtasks /run /tn ClaudeFoto' 2>/dev/null | tail -1
sleep 12
$S scp $O 'marietto@IP-WINDOWS-B:C:/claude/schermo.png' $D/schermo-wslg.png 2>/dev/null
timeout 30 $S ssh $O marietto@IP-WINDOWS-B 'type C:\claude\finestre.txt' 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r'
ls -la $D/schermo-wslg.png
