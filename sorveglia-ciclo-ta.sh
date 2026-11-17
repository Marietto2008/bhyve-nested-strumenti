#!/bin/sh
# sorveglia-ciclo-ta.sh -- Claude 12/11/2026: esce a fine giro (riga «esito:»), allo STOP/fine o se ciclo-ta.sh muore.
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-bhyve
C=$(ls -t $D/ciclo-ta-2026*.txt | head -1)
n0=$(/usr/bin/grep -c '  esito:' $C)
while :; do
	/usr/bin/grep -q 'STOP\|fine:' $C && break
	[ $(/usr/bin/grep -c '  esito:' $C) -gt $n0 ] && break
	pgrep -qf '^sh [^ ]*strumenti/ciclo-ta.sh' || { echo "ciclo-ta MORTO senza STOP"; break; }
	sleep 10
done
date +%T; tail -8 $C
