#!/bin/sh
# sorveglia-ciclo-kvm2.sh [fermati_a] -- Claude 11/11/2026: come sorveglia-ciclo-kvm.sh (esce a fine giro, allo STOP o se
# il ciclo muore), ma controlla ogni 2 s e, se il ciclo ha chiuso <fermati_a> giri, ferma ciclo-kvm.sh e la tempesta
# del giro successivo appena partita (che a quel punto e' ancora alla pulizia di WSL / allo sha: FreeBSD non e' avviata).
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-kvm
C=$(ls -t $D/ciclo-2026*.txt | head -1)
F=${1:-0}
n0=$(grep -c 'giro [0-9]*:' $C)
while :; do
	grep -q 'STOP\|fine:' $C && break
	n=$(grep -c 'giro [0-9]*:' $C)
	if [ $F -gt 0 ] && [ $n -ge $F ]; then
		pkill -f ciclo-kvm.sh; pkill -f tempesta-kvm2.sh
		echo "$(date +%T) fermato da sorveglia-ciclo-kvm2.sh dopo $n giri (richiesta: $F)" | tee -a $C
		break
	fi
	[ $n -gt $n0 ] && break
	pgrep -f ciclo-kvm.sh >/dev/null || { echo "ciclo-kvm MORTO senza STOP"; break; }
	sleep 2
done
tail -4 $C
echo ---
tail -7 $D/episodi-20261111-0306.txt
grep -a 'FERMO' $D/episodi-20261111-0306.txt | tail -3
pgrep -af 'tempesta-kvm2|ciclo-kvm' | grep -v sorveglia
