#!/bin/sh
# ciclo-ta.sh [giri_T] [giri_A] -- Claude 12/11/2026, braccio T della diagnosi 032 di Fable (§5.2), modulo t032.
# Sequenza T, T, A, ... fino a giri_T (base 20) giri T e giri_A (base 10) giri A validi. T = hw.vmm.vmx.nested_qual_kvm=1
# (qualificazione delle 48 come KVM, 0x48C b22 tolto), A = 0. La politica si legge alla creazione della VM: a ogni cambio
# di braccio Windows si spegne (shutdown via ssh, o SIGTERM a QEMU se la rete non c'e'), il residuo vm2 si toglie con
# vmm-residuo.sh e Windows riparte con avvio-rete.sh. Via 48 (nested_apic_access=0), svuotamento a 1 s.
# Regole (Fable 025 §4): panic in T -> STOP, tutto lasciato com'e'; panic in A -> dump salvato e si continua.
# Giro senza ESITO (claude-lag appeso) valido; console < 250 righe = giro non valido, non contato (3 di fila -> STOP).
set -u
NT=${1:-20}; NA=${2:-10}
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
W=/mnt/linuxulator2/vm/nested-work/caldo/vmm-residuo.sh
P=/home/marietto/.config/claude-wsl2/password-windows
C=$D/dati-bhyve/ciclo-ta-$(date +%Y%m%d-%H%M%S).txt
s() { sysctl -n hw.vmm.vmx.$1; }
dica() { echo "$(date +%T) $*" | tee -a $C; }
qemu_vivo() { pgrep -qf 'qemu-system.*vm0-13'; }

# 12/11 17:1x: dopo la riparazione della linea il DHCP di Fastweb ha dato a Windows .53 invece di .54: l'indirizzo
# si ricava dal MAC di vm0:13 nella tabella ARP (WIN_IP lo forza); se manca, un ping a .50-.60 riempie la tabella.
win_ip() {
	a=$(arp -an | awk '/00:a0:98:a1:73:65/ {gsub(/[()]/, "", $2); print $2; exit}')
	if [ -z "$a" ]; then
		for i in $(seq 50 60); do ping -c1 -t1 RETE-LAN.$i >/dev/null 2>&1; done
		a=$(arp -an | awk '/00:a0:98:a1:73:65/ {gsub(/[()]/, "", $2); print $2; exit}')
	fi
	echo ${a:-IP-WINDOWS-B}
}
WIN=${WIN_IP:-$(win_ip)}
spegni_win() {
	timeout 60 sshpass -f $P ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
	    -o PreferredAuthentications=password -o ConnectTimeout=15 marietto@$WIN 'shutdown /s /t 5' >/dev/null 2>&1
	i=0; while qemu_vivo && [ $i -lt 48 ]; do sleep 5; i=$((i + 1)); done
	if qemu_vivo; then
		dica "  Windows non si spegne in 4 min: SIGTERM a QEMU"
		sudo -n pkill -TERM -f 'qemu-system.*vm0-13'
		i=0; while qemu_vivo && [ $i -lt 24 ]; do sleep 5; i=$((i + 1)); done
	fi
	qemu_vivo && { dica "STOP: QEMU ancora vivo"; exit 4; }
	r=$(sudo -n sh $W --verifica 2>&1 | /usr/bin/grep '^vm2 ctime=')
	if [ -n "$r" ]; then
		ct=$(echo "$r" | sed 's/.*ctime=\([0-9]*\).*/\1/'); ms=$(echo "$r" | sed 's/.*memseg=\([0-9a-f]*\).*/\1/')
		[ "$ct" -ge "$T_AVVIO" ] || { dica "STOP: residuo vm2 piu' vecchio dell'avvio ($ct < $T_AVVIO)"; exit 4; }
		sudo -n sh $W --distruggi vm2 $ct $ms 2>&1 | tail -1 | sed 's/^/  /' | tee -a $C
	fi
}

avvia_win() {	# $1 = T o A
	q=0; [ "$1" = T ] && q=1
	for tent in 1 2; do
		sudo -n sysctl hw.vmm.vmx.nested_qual_kvm=$q >/dev/null
		T_AVVIO=$(date +%s)
		SONDA=0 sh $D/strumenti/avvio-rete.sh ta-$1 > /dev/null 2>&1
		R=$(ls -td $D/dati-bhyve/avvio-rete-*-ta-$1 | head -1)/riepilogo.txt
		dica "  Windows avviata, braccio $1 (nested_qual_kvm=$q): $(/usr/bin/grep -a 'esito rete' $R | cut -c10-)"
		dmesg | /usr/bin/grep 'vmm nested: 0x48B offerto' | tail -1 | sed 's/^/  /' | tee -a $C
		/usr/bin/grep -q 'esito rete: OK' $R && { BR=$1; return 0; }
		dica "  rete non partita: SIGTERM a QEMU e nuovo avvio"
		sudo -n pkill -TERM -f 'qemu-system.*vm0-13'; sleep 20
		spegni_win
	done
	dica "STOP: Windows senza rete due volte"; exit 4
}

[ "$(s nested_apic_access)" = 0 ] || { echo "STOP: nested_apic_access deve essere 0 (via 48)"; exit 4; }
[ "$(s nested_diag_amp_us)" = 0 ] || { echo "STOP: amplificatore acceso"; exit 4; }
dica "ciclo T,T,A: $NT giri T e $NA giri A; modulo $(sha256 -q /boot/kernel/vmm-restore.ko | cut -c1-8)"
BR=; T_AVVIO=0
qemu_vivo && { dica "STOP: Windows gia' accesa: spegnerla prima"; exit 4; }
kt=0; ka=0; inv=0; seq=0
while [ $kt -lt $NT ] || [ $ka -lt $NA ]; do
	# T, T, A; se un braccio e' completo si fa solo l'altro
	if [ $kt -ge $NT ]; then a=A; elif [ $ka -ge $NA ]; then a=T; elif [ $((seq % 3)) -eq 2 ]; then a=A; else a=T; fi
	if [ "$a" != "$BR" ]; then
		qemu_vivo && spegni_win
		avvia_win $a
	fi
	p0=$(( $(s nested_diag_pfrec_pf_fetch) + $(s nested_diag_pfrec_pf_data) )); e0=$(s nested_diag_pfrec_e0)
	if [ $a = T ]; then nn=$((kt + 1)); else nn=$((ka + 1)); fi
	dica "giro $a$nn (T fatti $kt, A fatti $ka)"
	sh $D/strumenti/tempesta-bhyve.sh svuota > $D/dati-bhyve/uscita-ciclo-ta.txt 2>&1
	G=$(ls -t $D/dati-bhyve/giro-*.txt | head -1)
	p1=$(( $(s nested_diag_pfrec_pf_fetch) + $(s nested_diag_pfrec_pf_data) )); e1=$(s nested_diag_pfrec_e0)
	n=$(wc -l < $D/dati-bhyve/console-$(basename $G .txt | sed 's/^giro-//').txt)
	dica "  esito: $(/usr/bin/grep -a 'panic' $G | tail -1 | cut -c10-) | E0 +$((e1 - e0)), #PF registrati +$((p1 - p0)), console $n righe | $G"
	echo "    e0c: $(for x in ilen ilen_ev altro altro_ev fermo fermo_ev; do printf '%s=%s ' $x $(s nested_diag_e0c_$x); done)" | tee -a $C
	s nested_diag_q48 | /usr/bin/grep 'pagina LAPIC' | cut -c1-300 | sed 's/^/    /' | tee -a $C
	if [ $p1 -gt $p0 ]; then
		s nested_diag_pfrec_dump > $D/dati-bhyve/registratore-PF-$(date +%Y%m%d-%H%M%S)-$a.txt
		dica "  #PF registrato dal modulo, dump salvato"
	fi
	if /usr/bin/grep -q 'PANIC' $G; then
		s nested_diag_pfrec_dump > $D/dati-bhyve/registratore-PANIC-$(date +%Y%m%d-%H%M%S)-$a.txt
		[ $a = T ] && { dica "STOP: PANIC NEL BRACCIO T (regola 1): tutto lasciato com'e'"; exit 0; }
		dica "  PANIC nel braccio A (regola 3): dump salvato, si continua"
	fi
	if [ $n -lt 250 ]; then
		inv=$((inv + 1)); dica "  giro NON valido (console corta), non contato"
		[ $inv -ge 3 ] && { dica "STOP: 3 giri non validi di fila"; exit 0; }
		continue
	fi
	inv=0
	/usr/bin/grep -q 'ESITO' $D/dati-bhyve/uscita-ciclo-ta.txt || dica "  senza ESITO (claude-lag appeso?)"
	if [ $a = T ]; then kt=$((kt + 1)); else ka=$((ka + 1)); fi
	seq=$((seq + 1))
done
dica "fine: $kt giri T e $ka giri A"
