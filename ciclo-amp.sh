#!/bin/sh
# ciclo-amp.sh <giri> -- Claude 11/11/2026, passo 1 della diagnosi 030 di Fable: amplificatore di tempo sotto bhyve
# (modulo amp030, via EPT violation: nested_apic_access=0). Come ciclo-bhyve.sh, ma in ogni giro il ritardo
# nested_diag_amp_us (AMP_US, ogni AMP_EVERY episodi) si accende a tempesta partita (300.000 episodi) + AMP_DOPO s, a WSL gia'
# partita (prima di allora l'avvio di FreeBSD resta come sempre), e si spegne a fine giro.
# Per ogni giro: esposizione E0->CR3 e istogrammi (nested_diag_e0_durata), episodi applicati, classi, #PF registrati.
# Si FERMA al primo panic in console, a una tempesta non finita o a una console corta (WSL non partita).
set -u
N=${1:-5}
AMP_US=${AMP_US:-500}; AMP_EVERY=${AMP_EVERY:-1}; AMP_DOPO=${AMP_DOPO:-0}
# 17/11 (Fable 073 par. 3.3): claude-lag in console di base, altrimenti i tempi (buchi, peggiore) del giro si perdono
CMDF=${CMDF:-freebsd-tempesta-console.sh}; export CMDF
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
C=$D/dati-bhyve/ciclo-amp-$(date +%Y%m%d-%H%M%S).txt
s() { sysctl -n hw.vmm.vmx.$1; }
pf() { echo $(( $(s nested_diag_pfrec_pf_fetch) + $(s nested_diag_pfrec_pf_data) )); }
[ "$(s nested_apic_access)" = 0 ] || { echo "STOP: nested_apic_access deve essere 0 (via 48)"; exit 4; }
echo "$(date +%T) ciclo-amp di $N giri: amp_us=$AMP_US every=$AMP_EVERY dopo=${AMP_DOPO}s" | tee -a $C
k=1
while [ $k -le $N ]; do
	sudo -n sysctl hw.vmm.vmx.nested_diag_amp_us=0 >/dev/null
	p0=$(pf); a0=$(s nested_diag_amp_applied); e0s=$(s nested_diag_pfrec_e0)
	echo "$(date +%T) giro $k di $N" | tee -a $C
	sh $D/strumenti/tempesta-bhyve.sh svuota > $D/dati-bhyve/uscita-ciclo-amp-giro$k.txt 2>&1 &
	tp=$!
	# 11/11 23:2x: non a tempo fisso (la pulizia di WSL e lo sha possono durare minuti): si attende la tempesta vera,
	# cioe' 300.000 episodi E0 in piu' dall'inizio del giro (circa 40 s di claude-lag), poi AMP_DOPO secondi
	while kill -0 $tp 2>/dev/null && [ $(( $(s nested_diag_pfrec_e0) - e0s )) -lt 300000 ]; do sleep 5; done
	sleep $AMP_DOPO
	if kill -0 $tp 2>/dev/null; then
		sudo -n sysctl hw.vmm.vmx.nested_diag_amp_every=$AMP_EVERY hw.vmm.vmx.nested_diag_amp_us=$AMP_US >/dev/null
		echo "$(date +%T)   amplificatore acceso" | tee -a $C
	fi
	wait $tp
	sudo -n sysctl hw.vmm.vmx.nested_diag_amp_us=0 >/dev/null
	G=$(ls -t $D/dati-bhyve/giro-*.txt | head -1)
	p1=$(pf); a1=$(s nested_diag_amp_applied)
	echo "$(date +%T) giro $k: $(/usr/bin/grep -a 'panic' $G | tail -1) | amplificati +$((a1 - a0)), #PF registrati +$((p1 - p0)) | $G" | tee -a $C
	echo "    e0c: $(for x in ilen ilen_ev altro altro_ev fermo fermo_ev senza_cr3; do printf '%s=%s ' $x $(s nested_diag_e0c_$x); done)" | tee -a $C
	s nested_diag_e0_durata | sed 's/^/    /' >> $C
	if [ $p1 -gt $p0 ]; then
		s nested_diag_pfrec_dump > $D/dati-bhyve/registratore-PF-$(date +%Y%m%d-%H%M%S).txt
		echo "$(date +%T) #PF registrato dal modulo, dump salvato" | tee -a $C
	fi
	/usr/bin/grep -q 'PANIC' $G && { echo "$(date +%T) STOP: panic nella console" | tee -a $C; exit 0; }
	# 12/11 00:33: col ritardo claude-lag puo' restare appeso (un thread in nanosleep, come il 10/11 alle 10:52): niente
	# ESITO, ma la tempesta c'e' stata e l'esposizione e' misurata. Si annota e si continua: la pulizia di WSL del giro
	# seguente chiude la sessione rimasta. Si ferma solo se in console c'e' un panic.
	# 16/11 (diagnosi 061 par. 2): contatori dopo ogni giro; con FERMA_SE_APPESO=1 un giro senza ESITO ferma il ciclo,
	# cosi' il blocco resta vivo per le letture (lettura-grezza.d, vept_rientro_*) prima di qualunque pulizia
	sh $D/strumenti/salva-contatori.sh "ciclo-amp giro $k di $N (rientro=$(sysctl -n hw.vmm.vmx.vept_keep_rientro 2>/dev/null))" >/dev/null
	if ! /usr/bin/grep -q 'ESITO' $D/dati-bhyve/uscita-ciclo-amp-giro$k.txt; then
		if [ "${FERMA_SE_APPESO:-0}" = 1 ]; then
			echo "$(date +%T) STOP: tempesta senza ESITO (claude-lag appeso?), ciclo fermato col blocco vivo" | tee -a $C
			exit 0
		fi
		echo "$(date +%T)   tempesta senza ESITO (claude-lag appeso?): si continua" | tee -a $C
	fi
	n=$(wc -l < $D/dati-bhyve/console-$(basename $G .txt | sed 's/^giro-//').txt)
	# 14/11: soglia sugli episodi, non sulle righe di console (vedi ciclo-bhyve.sh)
	[ $(( $(s nested_diag_pfrec_e0) - e0s )) -ge 1000000 ] || { echo "$(date +%T) STOP: meno di 1 M episodi E0 (console $n righe), la tempesta non e' partita" | tee -a $C; exit 0; }
	k=$((k + 1))
done
echo "$(date +%T) fine: $N giri senza eventi" | tee -a $C
