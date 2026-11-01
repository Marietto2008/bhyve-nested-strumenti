#!/bin/sh
# vnc-sorveglia.sh -- Claude 02/11/2026. Tiene aperto il visore VNC di una VM, MINIMIZZATO, anche dopo i riavvii
# del sistema ospite (bhyve esce e il visore si chiude). Gira come marietto, staccato (daemon -f).
# Uso: vnc-sorveglia.sh <nome VM, es. vm0:13> <display VNC, es. 13>
set -u
VM=$1; N=$2; P=$((5900 + N))
export DISPLAY=${DISPLAY:-:0} XAUTHORITY=${XAUTHORITY:-/home/marietto/.Xauthority}
assente=0
while :; do
	if [ -e "/dev/vmm/$VM" ]; then
		assente=0
		if ! pgrep -f "vncviewer localhost:$N\$" >/dev/null && nc -z -w 1 127.0.0.1 $P 2>/dev/null; then
			daemon -f /usr/local/bin/vncviewer localhost:$N
			i=0; while [ $i -lt 20 ]; do
				pid=$(pgrep -f "vncviewer localhost:$N\$" | head -1)
				w=$( [ -n "$pid" ] && xdotool search --pid "$pid" 2>/dev/null )
				[ -n "$w" ] && break
				i=$((i + 1)); sleep 1
			done
			sleep 2
			[ -n "${pid:-}" ] && for x in $(xdotool search --pid "$pid" 2>/dev/null); do xdotool windowminimize "$x" 2>/dev/null; done
		fi
	else
		# fra un riavvio e l'altro l'istanza manca per pochi secondi: si esce solo dopo 60 s di assenza
		assente=$((assente + 1)); [ $assente -gt 20 ] && exit 0
	fi
	sleep 3
done
