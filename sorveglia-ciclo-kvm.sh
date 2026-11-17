#!/bin/sh
# sorveglia-ciclo-kvm.sh -- Claude 11/11/2026: esce alla fine del giro in corso di ciclo-kvm.sh, allo STOP/fine o se
# il ciclo muore, stampando le ultime righe del ciclo e i contatori bpftrace (per richiamare Claude a ogni giro).
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-kvm
C=$(ls -t $D/ciclo-2026*.txt | head -1)
n0=$(grep -c 'giro [0-9]*:' $C)
while :; do
	grep -q 'STOP\|fine:' $C && break
	[ $(grep -c 'giro [0-9]*:' $C) -gt $n0 ] && break
	pgrep -f ciclo-kvm.sh >/dev/null || { echo "ciclo-kvm MORTO senza STOP"; break; }
	sleep 30
done
tail -3 $C
echo ---
tail -7 $D/episodi-20261111-0306.txt
grep -a 'FERMO' $D/episodi-20261111-0306.txt | tail -3
