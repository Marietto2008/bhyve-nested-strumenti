#!/bin/sh
# sorveglia-hyperv.sh -- Claude 13/11/2026: esce a fine giro di tempesta-hyperv.sh (riga «E0 +»), alla fine o se il ciclo muore.
G=/mnt/linuxulator2/vm/confronto-kvm-bhyve/hyperv/giri-hyperv.txt
n0=$(/usr/bin/grep -c 'E0 +' $G)
while :; do
	[ $(/usr/bin/grep -c 'E0 +' $G) -gt $n0 ] && break
	pgrep -qf '^sh [^ ]*tempesta-hyperv.sh' || { echo "tempesta-hyperv finito o morto"; break; }
	sleep 5
done
date +%T; tail -5 $G
