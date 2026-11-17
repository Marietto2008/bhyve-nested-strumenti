#!/bin/sh
# ciclo-mk.sh <giri> -- Claude 12/11/2026, amplificatore Mk della diagnosi 034 di Fable (§4.3), modulo m034, via 48,
# vCPU NON fissati. In ogni giro, a tempesta partita (300.000 episodi E0 in piu'), nested_diag_mk_modo=MK_MODO
# (base 1: X-Y-X) su un episodio normale ogni MK_EVERY (base 4); spento a fine giro. Al panic: dump salvato e si
# continua (criterio di Fable: 3 panic entro 2 giri = conferma); STOP a MK_MAXPANIC panic (base 3), a una console corta.
set -u
N=${1:-3}
MK_MODO=${MK_MODO:-1}; MK_EVERY=${MK_EVERY:-4}; MK_MAXPANIC=${MK_MAXPANIC:-3}
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
C=$D/dati-bhyve/ciclo-mk-$(date +%Y%m%d-%H%M%S).txt
s() { sysctl -n hw.vmm.vmx.$1; }
pf() { echo $(( $(s nested_diag_pfrec_pf_fetch) + $(s nested_diag_pfrec_pf_data) )); }
[ "$(s nested_apic_access)" = 0 ] || { echo "STOP: nested_apic_access deve essere 0 (via 48)"; exit 4; }
echo "$(date +%T) ciclo-mk di $N giri: modo=$MK_MODO every=$MK_EVERY" | tee -a $C
k=1; np=0
while [ $k -le $N ]; do
	sudo -n sysctl hw.vmm.vmx.nested_diag_mk_modo=0 >/dev/null
	p0=$(pf); e0s=$(s nested_diag_pfrec_e0); a0=$(s nested_diag_mk_andate); r0=$(s nested_diag_mk_ritorni)
	m0=$(s vpid01_invvpid_real_migration)
	echo "$(date +%T) giro $k di $N" | tee -a $C
	sh $D/strumenti/tempesta-bhyve.sh svuota > $D/dati-bhyve/uscita-ciclo-mk-giro$k.txt 2>&1 &
	tp=$!
	while kill -0 $tp 2>/dev/null && [ $(( $(s nested_diag_pfrec_e0) - e0s )) -lt 300000 ]; do sleep 5; done
	m1=$(s vpid01_invvpid_real_migration); t1=$(date +%s)
	if kill -0 $tp 2>/dev/null; then
		sudo -n sysctl hw.vmm.vmx.nested_diag_mk_every=$MK_EVERY hw.vmm.vmx.nested_diag_mk_modo=$MK_MODO >/dev/null
		echo "$(date +%T)   Mk acceso (migrazioni vere prima dell'accensione: +$((m1 - m0)))" | tee -a $C
	fi
	wait $tp
	sudo -n sysctl hw.vmm.vmx.nested_diag_mk_modo=0 >/dev/null
	G=$(ls -t $D/dati-bhyve/giro-*.txt | head -1)
	p1=$(pf); e1=$(s nested_diag_pfrec_e0)
	echo "$(date +%T) giro $k: $(/usr/bin/grep -a 'panic' $G | tail -1 | cut -c10-) | E0 +$((e1 - e0s)), andate +$(( $(s nested_diag_mk_andate) - a0 )), ritorni +$(( $(s nested_diag_mk_ritorni) - r0 )), uscita3 $(s nested_diag_mk_uscita), migrazioni vere +$(( $(s vpid01_invvpid_real_migration) - m0 )), #PF registrati +$((p1 - p0)) | $G" | tee -a $C
	echo "    e0c: $(for x in ilen ilen_ev altro altro_ev fermo fermo_ev; do printf '%s=%s ' $x $(s nested_diag_e0c_$x); done)" | tee -a $C
	[ $p1 -gt $p0 ] && { s nested_diag_pfrec_dump > $D/dati-bhyve/registratore-PF-$(date +%Y%m%d-%H%M%S)-mk.txt; echo "$(date +%T)   #PF registrato, dump salvato" | tee -a $C; }
	if /usr/bin/grep -q 'PANIC' $G; then
		np=$((np + 1)); echo "$(date +%T)   PANIC n. $np" | tee -a $C
		[ $np -ge $MK_MAXPANIC ] && { echo "$(date +%T) STOP: $np panic" | tee -a $C; exit 0; }
	fi
	n=$(wc -l < $D/dati-bhyve/console-$(basename $G .txt | sed 's/^giro-//').txt)
	if ! /usr/bin/grep -q 'PANIC' $G && [ $n -lt 250 ]; then echo "$(date +%T) STOP: console di $n righe, la tempesta non e' partita" | tee -a $C; exit 0; fi
	/usr/bin/grep -q 'ESITO' $D/dati-bhyve/uscita-ciclo-mk-giro$k.txt || echo "$(date +%T)   senza ESITO" | tee -a $C
	k=$((k + 1))
done
echo "$(date +%T) fine: $N giri, $np panic" | tee -a $C
