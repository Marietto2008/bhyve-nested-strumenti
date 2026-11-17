#!/bin/sh
# serie-forma-a.sh -- claude 17/11/2026 (Fable 069 par. 4.2): serie mirata per la forma A del guasto della rete
# (tutte le tabelle MSI-X vuote al PRIMO avvio di Windows con uno stato del vmm nuovo). Per ogni ciclo:
#   1. residuo vm2 distrutto (vmm-residuo.sh) e RICARICA A CALDO del modulo in /boot (caldo-ricarica.sh, SHA atteso);
#   2. avvio di Windows su un OVERLAY NUOVO (vm0-13-qemu.sh --overlay: il disco vero non si scrive), VNC minimizzata;
#   3. verdetto del sorvegliante della rete (sorveglia-rete.sh, avviato dal lanciatore, scrive la riga d'avvio);
#   4. rete buona: shutdown /s e ciclo seguente; rete guasta: il kit e' gia' stato lanciato dal sorvegliante, QEMU si
#      chiude con quit QMP (su overlay non costa nulla) e la serie si ferma (FERMA=0 per andare avanti).
# Gira come marietto (sudo -n per le parti di root). Il consenso dell'utente va chiesto PRIMA: ricarica il modulo N volte.
#   SHA=<sha256 del modulo in /boot> sh serie-forma-a.sh [N=9]
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
N=${1:-9}
SHA=${SHA:?manca SHA=<sha256 del modulo in /boot>}
FERMA=${FERMA:-1}
B=/mnt/linuxulator2/vm/confronto-kvm-bhyve
D=$B/dati-bhyve
PF=/home/marietto/.config/claude-wsl2/password-windows
Q=/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock
LOG=$D/serie-forma-a-$(date +%Y%m%d-%H%M%S).txt
dice() { echo "$(date '+%H:%M:%S') $*" | tee -a $LOG; }
qemu_vivo() { ps -ax -o comm= | grep -q qemu-system; }
qmp_quit() { sudo -n python3.12 -c "
import socket, json
s = socket.socket(socket.AF_UNIX); s.connect('$Q'); f = s.makefile('rw'); f.readline()
for c in ('qmp_capabilities', 'quit'):
    f.write(json.dumps({'execute': c}) + '\n'); f.flush()
    try: f.readline()
    except Exception: pass
" 2>/dev/null; }
aspetta_uscita() {	# $1 = secondi
	i=0; while qemu_vivo && [ $i -lt $1 ]; do sleep 3; i=$((i + 3)); done
	! qemu_vivo
}
residuo() {
	V=$(sudo -n sh /mnt/linuxulator2/vm/nested-work/caldo/vmm-residuo.sh --verifica 2>&1 | tail -1)
	C=$(echo "$V" | sed -n 's/.*ctime=\([0-9]*\).*/\1/p'); M=$(echo "$V" | sed -n 's/.*memseg=\([0-9a-f]*\).*/\1/p')
	[ -n "$C" ] && sudo -n sh /mnt/linuxulator2/vm/nested-work/caldo/vmm-residuo.sh --distruggi vm2 $C $M 2>&1 | tail -1 >> $LOG
}

dice "serie forma A: $N cicli, modulo atteso $(echo $SHA | cut -c1-8), FERMA=$FERMA"
qemu_vivo && { dice "STOP: QEMU gia' vivo (spegnere Windows prima)"; exit 4; }
k=1; guasti=0
while [ $k -le $N ]; do
	dice "== ciclo $k/$N"
	residuo
	if ! sudo -n env SHA=$SHA sh $B/strumenti/caldo-ricarica.sh --esegui >> $LOG 2>&1; then
		dice "STOP: caldo-ricarica.sh non e' finito con 0 (vedi $LOG)"; exit 4
	fi
	sudo -n sysctl hw.vmm.vmx.nested_diag_pfrec=1 hw.vmm.vmx.nested_diag_amp_us=0 >/dev/null
	t0=$(date +%s)
	A=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs/vm0-13-avvio-$(date +%Y%m%d-%H%M%S).txt
	sudo -n daemon -o $A sh /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/vm0-13-qemu.sh --qemu-sipi --audio --overlay
	sleep 8
	DISPLAY=:0 daemon -f vncviewer 127.0.0.1:5913; sleep 3
	for w in $(DISPLAY=:0 xdotool search --name 'vm0-13' 2>/dev/null); do DISPLAY=:0 xdotool windowminimize $w; done
	# il registro del sorvegliante di questo avvio: il primo sorveglia-rete-*.txt piu' nuovo dell'avvio
	S=""; i=0
	while [ -z "$S" ] && [ $i -lt 60 ]; do
		S=$(find $D -maxdepth 1 -name 'sorveglia-rete-*.txt' ! -name '*-codici.txt' ! -name '*-anello.txt' -newer $A 2>/dev/null | head -1)
		sleep 2; i=$((i + 2))
	done
	[ -n "$S" ] || { dice "STOP: il sorvegliante non e' partito (vedi $A)"; exit 4; }
	esito=""; i=0
	while [ -z "$esito" ] && [ $i -lt 1200 ]; do
		grep -q 'RETE OK' $S && esito=ok
		grep -q 'GUASTO RILEVATO' $S && esito=guasto
		grep -q 'QEMU uscito' $S && [ -z "$esito" ] && esito=uscito
		sleep 5; i=$((i + 5))
	done
	dice "ciclo $k: esito ${esito:-scaduto} dopo $(( $(date +%s) - t0 )) s ($S)"
	# il sorvegliante scrive la riga d'avvio (Kernel-Power 41) e poi esce: si aspetta che finisca (al massimo 2 min)
	i=0; while pgrep -f "sh $B/strumenti/sorveglia-rete.sh" >/dev/null && [ $i -lt 120 ]; do sleep 3; i=$((i + 3)); done
	case "$esito" in
	ok)
		timeout 60 sshpass -f $PF ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 marietto@IP-WINDOWS-A \
		    'shutdown /s /t 3 /c "claude: serie forma A"' >/dev/null 2>&1
		if ! aspetta_uscita 300; then dice "shutdown non riuscito in 300 s: quit QMP (overlay)"; qmp_quit; aspetta_uscita 60; fi
		;;
	guasto)
		guasti=$((guasti + 1))
		dice "★ ciclo $k: RETE GUASTA, kit gia' lanciato dal sorvegliante; quit QMP (overlay)"
		qmp_quit; aspetta_uscita 60
		[ "$FERMA" = 1 ] && { dice "serie fermata al primo guasto (ciclo $k/$N)"; residuo; exit 0; }
		;;
	*)
		dice "ciclo $k: esito '${esito:-scaduto}': quit QMP e STOP"
		qemu_vivo && qmp_quit; aspetta_uscita 60; residuo; exit 4
		;;
	esac
	qemu_vivo && { dice "STOP: QEMU ancora vivo dopo lo spegnimento"; exit 4; }
	k=$((k + 1))
done
residuo
dice "fine serie: $N cicli, $guasti guasti"
