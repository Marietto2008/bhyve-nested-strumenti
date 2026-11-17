#!/bin/sh
# sorveglia-whpx.sh -- Claude 12/11/2026: esce a fine giro di tempesta-whpx.sh (riga «E0 +»), alla fine o se il ciclo muore.
G=/mnt/linuxulator2/vm/confronto-kvm-bhyve/qemu-whpx/giri-whpx.txt
n0=$(/usr/bin/grep -c 'E0 +' $G)
while :; do
	[ $(/usr/bin/grep -c 'E0 +' $G) -gt $n0 ] && break
	pgrep -qf '^sh [^ ]*tempesta-whpx.sh' || { echo "tempesta-whpx finito o morto"; break; }
	sleep 5
done
date +%T; tail -5 $G
