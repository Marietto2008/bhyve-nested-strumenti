#!/bin/sh
# ciclo-kvm.sh <giri> -- Claude 11/11/2026, giro lungo sotto KVM della risposta di Fable al 023 (§3).
# Ripete tempesta-kvm2.sh svuota (PTI forzato nell'L2, svuotamento a 1 s ritardato di 120 s, come i giri bhyve) fino a
# <giri> e si FERMA al primo panic nella console di FreeBSD (lasciando Windows e l'L2 come sono) o se la tempesta non
# finisce (niente «ESITO»). Il conteggio degli episodi lo fa a parte bpftrace (kvm-episodi-linux.bt, con sudo).
# Riepilogo in ../dati-kvm/ciclo-<ora>.txt.
set -u
N=${1:-12}
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
C=$D/dati-kvm/ciclo-$(date +%Y%m%d-%H%M%S).txt
export AVVIO=${AVVIO:-prova-wsl-vhd-pti.ps1} SVUOTA_PAUSA=${SVUOTA_PAUSA:-1000} SVUOTA_RITARDO=${SVUOTA_RITARDO:-120}
echo "$(date +%T) ciclo di $N giri: avvio=$AVVIO svuota_pausa=$SVUOTA_PAUSA ritardo=$SVUOTA_RITARDO" | tee -a $C
k=1
while [ $k -le $N ]; do
	echo "$(date +%T) giro $k di $N" | tee -a $C
	sh $D/strumenti/tempesta-kvm2.sh svuota > $D/dati-kvm/uscita-ciclo-giro$k.txt 2>&1
	G=$(ls -t $D/dati-kvm/giro-*.txt | head -1)
	sv=$(grep -a -o 'fine [0-9:.]* ok=[0-9]*' $G | tail -1)
	echo "$(date +%T) giro $k: $(tail -1 $G) | svuotamenti: ${sv:-?} | $G" | tee -a $C
	grep -q 'PANIC' $G && { echo "$(date +%T) STOP: PANIC nella console di FreeBSD" | tee -a $C; exit 0; }
	grep -q 'ESITO' $D/dati-kvm/uscita-ciclo-giro$k.txt || { echo "$(date +%T) STOP: tempesta non finita" | tee -a $C; exit 0; }
	# 11/11 13:10: WSL in ERROR_TIMEOUT all'avvio (console ferma al montaggio della radice, 131 righe) e il giro e'
	# passato per «nessun panic»: ESITO c'e' comunque. Un giro vero ha 230-300 righe di console.
	n=$(wc -l < $D/dati-kvm/console-$(basename $G .txt | sed 's/^giro-//').txt)
	[ $n -ge 200 ] || { echo "$(date +%T) STOP: console di $n righe, la tempesta non e' partita" | tee -a $C; exit 0; }
	k=$((k + 1))
done
echo "$(date +%T) fine: $N giri senza panic" | tee -a $C
