#!/bin/sh
# avvia-vm0-13.sh -- Claude 02/11/2026. Avvia la VM Windows clone vm0:13 CON la finestra VNC aperta e MINIMIZZATA
# (richiesta dell'utente: «Fa partire le vm windows con la finestra vnc aperta e minimizzata»).
# Gira come marietto: la VM parte con sudo (vm0-13-wsl2-freebsd.sh, staccata con daemon), il visore nella sessione X.
set -u
D=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl
LOGS=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs
export DISPLAY=${DISPLAY:-:0} XAUTHORITY=${XAUTHORITY:-/home/marietto/.Xauthority}
L=$LOGS/vm0-13-$(date +%Y%m%d-%H%M%S).log
sudo -n /usr/sbin/daemon -o "$L" /bin/sh $D/vm0-13-wsl2-freebsd.sh || { echo "avvio non riuscito"; exit 4; }
# la porta VNC compare solo se i controlli dello script sono passati e bhyve e' vivo
i=0; until nc -z -w 1 127.0.0.1 5913 2>/dev/null; do
	i=$((i + 1)); [ $i -gt 30 ] && { echo "VNC 5913 non risponde dopo 30 s; registro: $L"; cat "$L"; exit 4; }
	sleep 1
done
daemon -f /usr/local/bin/vncviewer localhost:13
# minimizzare: la finestra compare dopo qualche istante
i=0; while :; do
	pid=$(pgrep -f 'vncviewer localhost:13' | head -1)
	w=$( [ -n "$pid" ] && xdotool search --pid "$pid" 2>/dev/null )
	[ -n "$w" ] && break
	i=$((i + 1)); [ $i -gt 20 ] && { echo "finestra VNC non trovata (resta aperta, non minimizzata)"; exit 0; }
	sleep 1
done
sleep 2
for x in $(xdotool search --pid "$pid"); do xdotool windowminimize "$x" 2>/dev/null; done
echo "vm0:13 avviata; VNC localhost:13 aperta e minimizzata; registro $L"
