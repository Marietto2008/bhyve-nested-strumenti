#!/bin/sh
# prova-vhd.sh <nome VHD> -- copia il VHD in Windows, lancia prova-wsl-vhd.ps1 nella sessione e raccoglie la console
V=$1; EXTRA=${2:-}; S="sshpass -f /home/marietto/.config/claude-wsl2/password-windows"; O="-o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o ConnectTimeout=20"
I=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini
D=/tmp/claude-1001/-mnt-linuxulator2-freebsd-radxa-src/5c397449-f584-4e61-9504-47b7fe6ab862/scratchpad
sh $D/pulisci-wsl.sh
$S scp $O /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/prova-wsl-vhd.ps1 /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/prova-wsl-fbsd.ps1 /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/scrivi-console.ps1 "marietto@IP-WINDOWS-B:C:/claude/" 2>/dev/null
h=$(timeout 300 $S ssh $O marietto@IP-WINDOWS-B "powershell -NoProfile -Command \"if (Test-Path C:\\claude\\wsl-fbsd\\$V.vhd) { (Get-FileHash C:\\claude\\wsl-fbsd\\$V.vhd).Hash }\"" 2>/dev/null | tr -d '\r' | tr 'A-F' 'a-f' | grep -E '^[0-9a-f]{64}$')
[ "$h" = "$(cat $I/$V.vhd.sha256)" ] && echo "VHD gia' in Windows, niente copia" || $S scp $O $I/$V.vhd "marietto@IP-WINDOWS-B:C:/claude/wsl-fbsd/$V.vhd" 2>/dev/null
h=$(timeout 300 $S ssh $O marietto@IP-WINDOWS-B "powershell -NoProfile -Command \"(Get-FileHash C:\\claude\\wsl-fbsd\\$V.vhd).Hash\"" 2>/dev/null | tr -d '\r' | tr 'A-F' 'a-f' | grep -E '^[0-9a-f]{64}$')
[ "$h" = "$(cat $I/$V.vhd.sha256)" ] && echo "sha in Windows ok" || { echo "SHA DIVERSO: $h"; exit 1; }
timeout 60 $S ssh $O marietto@IP-WINDOWS-B "schtasks /end /tn ClaudeProvaWslVhd >nul 2>&1 & del C:\\claude\\wsl-fbsd\\console-wsl.txt 2>nul & del C:\\claude\\prova-wsl-fbsd.log 2>nul & schtasks /create /tn ClaudeProvaWslVhd /tr \"powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\prova-wsl-vhd.ps1 -Vhd $V $EXTRA\" /sc once /sd 01/01/2020 /st 00:00 /it /f >nul && schtasks /run /tn ClaudeProvaWslVhd" 2>/dev/null | tail -1
F=$D/wsl-$V.txt; t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 1500 ]; do
	r=$(timeout 30 $S ssh $O marietto@IP-WINDOWS-B 'type C:\claude\prova-wsl-fbsd.log' 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r')
	echo "$r" | grep -q 'ESITO' && break; sleep 10
done
timeout 30 $S ssh $O marietto@IP-WINDOWS-B 'type C:\claude\wsl-fbsd\console-wsl.txt' 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' > $F
echo "$r" | sed -n '/^\[claude\] [0-9:]* 2\./,/^ESITO/p' | grep -v '^$'
echo "--- console: $F"
