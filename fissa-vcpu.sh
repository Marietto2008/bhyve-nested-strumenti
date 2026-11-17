#!/bin/sh
# fissa-vcpu.sh [schema] -- Claude 12/11/2026, braccio P della diagnosi 034 di Fable (§4.2): i thread dei vCPU di QEMU
# (vm0-13) fissati uno per core fisico (vCPU i -> CPU logica 2i: 0,2,...,14), gli altri thread di QEMU sulle CPU dispari.
# Schema «S» (§4.4, prelazione senza migrazione): vCPU i e i+4 sulla stessa CPU logica 2*(i%4) (0,2,4,6), gli altri
# thread di QEMU sulle CPU 8-15. I vCPU si riconoscono campionando procstat -t: sono i thread visti in «vmidle»
# (attesa dell'HLT del vCPU) o in esecuzione; in ordine di TID = vCPU 0..7. Stampa l'assegnazione.
set -u
S=${1:-P}
Q=$(pgrep -f 'qemu-system.*vm0-13') || { echo "QEMU non trovato"; exit 4; }
V=
for i in $(seq 1 120); do
	V=$(printf '%s\n' $V $(procstat -t $Q | awk '$8 == "vmidle" {print $2}') | sort -un)
	[ $(printf '%s\n' $V | /usr/bin/grep -c .) -ge 8 ] && break
	sleep 0.5
done
n=$(printf '%s\n' $V | /usr/bin/grep -c .)
[ $n -eq 8 ] || { echo "trovati $n thread vCPU, non 8: $V"; exit 4; }
k=0
for t in $V; do
	if [ "$S" = S ]; then c=$((2 * (k % 4))); else c=$((2 * k)); fi
	sudo -n cpuset -l $c -t $t && echo "vCPU$k tid $t -> CPU $c"
	k=$((k + 1))
done
if [ "$S" = S ]; then altre=8-15; else altre=1,3,5,7,9,11,13,15; fi
for t in $(procstat -t $Q | awk 'NR > 1 {print $2}'); do
	printf '%s\n' $V | /usr/bin/grep -qx $t || sudo -n cpuset -l $altre -t $t
done
echo "altri thread di QEMU -> CPU $altre"
