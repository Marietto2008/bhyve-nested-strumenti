#!/bin/sh
# sorveglia-ciclo-mk.sh -- Claude 12/11/2026: esce a fine giro, alla prima accensione di Mk (riga «Mk acceso»), allo
# STOP/fine o se ciclo-mk.sh muore.
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-bhyve
C=$(ls -t $D/ciclo-mk-2026*.txt | head -1)
g0=$(/usr/bin/grep -c 'giro [0-9]*:' $C); a0=$(/usr/bin/grep -c 'Mk acceso' $C)
while :; do
	/usr/bin/grep -q 'STOP\|fine:' $C && break
	[ $(/usr/bin/grep -c 'giro [0-9]*:' $C) -gt $g0 ] && break
	[ $(/usr/bin/grep -c 'Mk acceso' $C) -gt $a0 ] && { sleep 60; echo "andate $(sysctl -n hw.vmm.vmx.nested_diag_mk_andate) ritorni $(sysctl -n hw.vmm.vmx.nested_diag_mk_ritorni) un minuto dopo l'accensione"; break; }
	pgrep -qf '^sh [^ ]*strumenti/ciclo-mk.sh' || { echo "ciclo-mk MORTO senza STOP"; break; }
	sleep 10
done
date +%T; tail -6 $C
