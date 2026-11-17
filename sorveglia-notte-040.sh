#!/bin/sh
# sorveglia-notte-040.sh -- Claude 14/11/2026: esce alla prima riga nuova di fine fase/giro nel registro della notte, o se
# notte-040.sh non gira piu'.
L=$(ls -t /mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-bhyve/notte-040-*.txt | head -1)
P='FASE|fine [ABC]|FINE|PANIC|STOP|nessun panic|E0 \+|giro [0-9]+:'
n0=$(/usr/bin/grep -c -E "$P" $L)
while :; do
	[ $(/usr/bin/grep -c -E "$P" $L) -gt $n0 ] && break
	pgrep -f '^sh [^ ]*notte-040.sh' >/dev/null || { echo "notte-040 finita o morta"; break; }
	sleep 10
done
date +%T; tail -4 $L | cut -c1-300
