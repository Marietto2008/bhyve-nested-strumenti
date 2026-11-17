#!/bin/sh
# sorveglia-ciclo-bhyve.sh -- Claude 11/11/2026: esce a fine giro, allo STOP/fine o se ciclo-bhyve.sh muore.
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-bhyve
C=$(ls -t $D/ciclo-2026*.txt | head -1)
n0=$(/usr/bin/grep -c 'giro [0-9]*:' $C)
while :; do
	/usr/bin/grep -q 'STOP\|fine:' $C && break
	n=$(/usr/bin/grep -c 'giro [0-9]*:' $C); [ $n -gt $n0 ] && break
	pgrep -f "^sh [^ ]*strumenti/ciclo-bhyve.sh" >/dev/null || { echo "ciclo-bhyve MORTO senza STOP"; break; }
	sleep 10
done
date +%T; tail -5 $C
