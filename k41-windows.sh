#!/bin/sh
# k41.sh -- claude 17/11/2026 (Fable 069 par. 4.4): quanti Kernel-Power 41 (arresto precedente non regolare) ha
# registrato Windows nell'avvio in corso. Stampa il numero, o niente se Windows non risponde in ~1 minuto.
PF=/home/marietto/.config/claude-wsl2/password-windows
i=0
while [ $i -lt 6 ]; do
	n=$(sshpass -f $PF ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 marietto@IP-WINDOWS-A \
	    "powershell -NoProfile -Command \"(Get-WinEvent -FilterHashtable @{LogName='System';Id=41;StartTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime} -ErrorAction SilentlyContinue | Measure-Object).Count\"" 2>/dev/null | tr -d '\r' | tail -1)
	case "$n" in [0-9]*) echo "$n"; exit 0;; esac
	i=$((i + 1)); sleep 8
done
exit 1
