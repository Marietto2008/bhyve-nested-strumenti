#!/bin/sh
# ciclo-bhyve.sh <giri> -- Claude 10/11/2026, giri di base sotto bhyve (diagnosi Fable 018 §4.6) col registratore.
# Ripete tempesta-bhyve.sh svuota fino a <giri> e si FERMA al primo evento, lasciando Windows e FreeBSD-L2 come sono:
#   - panic nella console di FreeBSD (Fatal trap);
#   - #PF registrato dal modulo (nested_diag_pfrec_pf_fetch/_data cresciuti): dump salvato subito;
#   - tempesta non finita (niente «ESITO» nel registro del giro: claude-lag appeso come alle 10:52).
# Per ogni giro: riga in ../dati-bhyve/ciclo-<ora>.txt con contatori del registratore prima/dopo.
set -u
N=${1:-4}
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
C=$D/dati-bhyve/ciclo-$(date +%Y%m%d-%H%M%S).txt
pf() { echo $(( $(sysctl -n hw.vmm.vmx.nested_diag_pfrec_pf_fetch) + $(sysctl -n hw.vmm.vmx.nested_diag_pfrec_pf_data) )); }
k=1
while [ $k -le $N ]; do
	p0=$(pf); e0=$(sysctl -n hw.vmm.vmx.nested_diag_pfrec_e0); m0=$(sysctl -n hw.vmm.vmx.vpid01_invvpid_real_migration)
	echo "$(date +%T) giro $k di $N" | tee -a $C
	sh $D/strumenti/tempesta-bhyve.sh svuota > $D/dati-bhyve/uscita-ciclo-giro$k.txt 2>&1
	G=$(ls -t $D/dati-bhyve/giro-*.txt | head -1)
	p1=$(pf); e1=$(sysctl -n hw.vmm.vmx.nested_diag_pfrec_e0)
	echo "$(date +%T) giro $k: $(tail -2 $G | head -1) | episodi E0 +$((e1 - e0)), #PF registrati +$((p1 - p0)) | $G" | tee -a $C
	# Fable 022 §3.1d: classificazione degli episodi (cumulativa dall'avvio dell'host)
	echo "    e0c: $(for x in ilen ilen_ev altro altro_ev fermo fermo_ev altrovmcs; do printf '%s=%s ' $x $(sysctl -n hw.vmm.vmx.nested_diag_e0c_$x); done)svuota_pausa=${SVUOTA_PAUSA:-1000}" | tee -a $C
	# 11/11: via APIC-access (nested_apic_access=1): uscite 44 riflesse, cumulative
	echo "    migrazioni vere del vCPU (vpid01_invvpid_real_migration) nel giro: +$(( $(sysctl -n hw.vmm.vmx.vpid01_invvpid_real_migration) - m0 ))" | tee -a $C
	echo "    apicacc: policy=$(sysctl -n hw.vmm.vmx.nested_apic_access) exits=$(sysctl -n hw.vmm.vmx.nested_apicacc_exits) entries=$(sysctl -n hw.vmm.vmx.nested_apicacc_entries)" | tee -a $C
	# 10/11 20:2x: il #PF registrato puo' essere FALSO (episodio chiuso dopo una migrazione del VP: fault utente
	# di un altro momento). Si salva il dump, ma ci si ferma solo sul panic vero nella console.
	if [ $p1 -gt $p0 ]; then
		sysctl -n hw.vmm.vmx.nested_diag_pfrec_dump > $D/dati-bhyve/registratore-PF-$(date +%Y%m%d-%H%M%S).txt
		echo "$(date +%T) #PF registrato dal modulo, dump salvato (si continua se la console non ha panic)" | tee -a $C
	fi
	grep -q 'PANIC' $G && { echo "$(date +%T) STOP: panic nella console" | tee -a $C; exit 0; }
	grep -q 'ESITO' $D/dati-bhyve/uscita-ciclo-giro$k.txt || { echo "$(date +%T) STOP: tempesta non finita (claude-lag appeso?)" | tee -a $C; exit 0; }
	# 11/11: come ciclo-kvm.sh, un giro con WSL non partita (console corta) non e' un giro valido
	# 14/11: le righe di console non distinguono piu' (WSL fallita con ERROR_TIMEOUT: 211; giri buoni: 222 e 227).
	# Un giro e' valido se la tempesta ha prodotto episodi: fallito ~87 k, buono ~11 M. Soglia 1 M.
	n=$(wc -l < $D/dati-bhyve/console-$(basename $G .txt | sed 's/^giro-//').txt)
	# 14/11 03:56: WSL a volte non parte (Wsl/Service/CreateInstance/ERROR_TIMEOUT, ~1 giro su 8): il giro non conta e
	# si ripete; dopo 3 giri non validi di fila ci si ferma.
	if [ $((e1 - e0)) -lt 1000000 ]; then
		nv=$((${nv:-0} + 1))
		echo "$(date +%T) giro NON valido: solo $((e1 - e0)) episodi E0 (console $n righe), la tempesta non e' partita ($nv di fila)" | tee -a $C
		[ $nv -lt 3 ] || { echo "$(date +%T) STOP: 3 giri non validi di fila" | tee -a $C; exit 0; }
		continue
	fi
	nv=0
	k=$((k + 1))
done
echo "$(date +%T) fine: $N giri senza eventi" | tee -a $C
