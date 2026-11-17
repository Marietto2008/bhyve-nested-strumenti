#!/bin/sh
# esperimento-riorg.sh -- claude 17/11/2026 (Fable 073 par. 2.3): la riorganizzazione settimanale del registro provocata su un
# overlay, senza spostare l'orologio. Per ogni ripetizione:
#   1. overlay nuovo dal disco vero (come vm0-13-qemu.sh --overlay: qemu-img + copia delle variabili OVMF);
#   2. intestazione di SOFTWARE e DEFAULT con 0xA8 8 giorni indietro (riorg-intestazione.py: controlli prima, altrimenti
#      niente), scritta con qemu-io SOLO nell'overlay e riletta;
#   3. avvio con OVL_RIUSA, modulo di adesso, niente ricarica (VM non la prima dal caricamento);
#   4. verdetto del sorvegliante e riga d'avvio (deve comparire kg15 con SOFTWARE e DEFAULT, se no l'innesco non e' scattato);
#   5. rete buona: shutdown /s; rete guasta: kit gia' lanciato, quit QMP (overlay: nessun danno).
# Il disco vero non si scrive mai. Consenso dell'utente 17/11 («Si', procedi»).
#   [RICARICA=1] sh esperimento-riorg.sh [N=3]    RICARICA=1: ricarica a caldo del modulo prima di ogni avvio
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
N=${1:-3}
RICARICA=${RICARICA:-0}
SHA=${SHA:-96d52f3d72181901b2f609d4354ad85c1f759973651862d6eb17420e917ef060}	# HCALL4, il modulo in /boot
B=/mnt/linuxulator2/vm/confronto-kvm-bhyve
D=$B/dati-bhyve
PF=/home/marietto/.config/claude-wsl2/password-windows
Q=/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock
OVD=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/overlay
VARS=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/vm0-13-qemu-vars.fd
IMG=/mnt/da1p2/bhyve/img/Windows/11/Windows11-wsl2-freebsd.img	# 17/11 sera: di nuovo il G-DRIVE (decisione dell'utente)
POFF=122683392; CL=4096
# hive, LCN del primo cluster (fsutil file queryextents, 17/11 13:1x), ora attesa di 0xA8 (UTC, dai KG15 del 17/11)
HIVE="SOFTWARE:0x1d72aa6:2026-11-17 07:21:44 DEFAULT:0xe2eda:2026-11-17 07:22:04"
LOG=$D/esperimento-riorg-$(date +%Y%m%d-%H%M%S).txt
TMP=/tmp/claude-1001/-mnt-linuxulator2-freebsd-radxa-src/5c397449-f584-4e61-9504-47b7fe6ab862/scratchpad
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
aspetta_uscita() { i=0; while qemu_vivo && [ $i -lt $1 ]; do sleep 3; i=$((i + 3)); done; ! qemu_vivo; }
residuo() {
	V=$(sudo -n sh /mnt/linuxulator2/vm/nested-work/caldo/vmm-residuo.sh --verifica 2>&1 | tail -1)
	C=$(echo "$V" | sed -n 's/.*ctime=\([0-9]*\).*/\1/p'); M=$(echo "$V" | sed -n 's/.*memseg=\([0-9a-f]*\).*/\1/p')
	[ -n "$C" ] && sudo -n sh /mnt/linuxulator2/vm/nested-work/caldo/vmm-residuo.sh --distruggi vm2 $C $M 2>&1 | tail -1 >> $LOG
}

dice "esperimento riorganizzazione: $N ripetizioni"
qemu_vivo && { dice "STOP: QEMU vivo (spegnere Windows prima)"; exit 4; }
k=1
while [ $k -le $N ]; do
	dice "== ripetizione $k/$N"
	residuo
	# 073 par. 2.3, seconda lettura: stato nuovo del vmm piu' riorganizzazione (come il 17/11 08:20)
	if [ "${RICARICA:-0}" = 1 ]; then
		sudo -n env SHA=$SHA sh $B/strumenti/caldo-ricarica.sh --esegui >> $LOG 2>&1 || { dice "STOP: caldo-ricarica.sh non e' finito con 0"; exit 4; }
		dice "modulo ricaricato a caldo ($(echo $SHA | cut -c1-8)), vm_create $(sysctl -n hw.vmm.vmx.vm_create)"
	fi
	T=$(date +%Y%m%d-%H%M%S); OV=$OVD/vm0-13-overlay-$T.qcow2; OVV=$OVD/vm0-13-qemu-vars-$T.fd
	sudo -n /usr/local/bin/qemu-img create -q -f qcow2 -b "$IMG" -F raw "$OV" && sudo -n cp -p "$VARS" "$OVV" || { dice "STOP: overlay non creato"; exit 4; }
	ok=1
	for h in $(echo "$HIVE" | tr ' ' '\n' | sed -n 's/^\([A-Z]*\):\(0x[0-9a-f]*\):.*/\1:\2/p'); do
		nome=${h%%:*}; lcn=${h#*:}
		ora="$(echo "$HIVE" | sed -n "s/.*$nome:$lcn:\([0-9-]* [0-9:]*\).*/\1/p")"
		off=$(( POFF + lcn * CL ))
		if ! python3.12 $B/strumenti/riorg-intestazione.py "$IMG" $off "$ora" $TMP/riorg-$nome.bin 8 >> $LOG 2>&1; then
			dice "$nome: controllo fallito (vedi $LOG), niente scrittura"; ok=0; break
		fi
		sudo -n /usr/local/bin/qemu-io -f qcow2 "$OV" -c "write -s $TMP/riorg-$nome.bin $off 512" >> $LOG 2>&1 || { dice "$nome: qemu-io write fallito"; ok=0; break; }
		# rilettura dall'overlay: i 512 byte devono essere quelli preparati
		sudo -n /usr/local/bin/qemu-io -r -f qcow2 "$OV" -c "read -v $off 512" 2>/dev/null | awk '/^[0-9a-f]+:  /{for (i = 2; i <= 17; i++) printf "%s", $i}' > $TMP/riorg-$nome.letto
		[ "$(cat $TMP/riorg-$nome.letto)" = "$(od -A n -t x1 -v $TMP/riorg-$nome.bin | tr -d ' \n')" ] || { dice "$nome: rilettura diversa da quanto scritto"; ok=0; break; }
		dice "$nome: intestazione scritta nell'overlay e riletta (offset $off)"
	done
	[ $ok = 1 ] || { dice "STOP: ripetizione $k non preparata; overlay $OV lasciato inutilizzato"; exit 4; }
	sudo -n sysctl hw.vmm.vmx.nested_diag_pfrec=1 hw.vmm.vmx.nested_diag_amp_us=0 >/dev/null
	t0=$(date +%s)
	A=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs/vm0-13-avvio-$(date +%Y%m%d-%H%M%S).txt
	sudo -n env OVL_RIUSA="$OV" daemon -o $A sh /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/vm0-13-qemu.sh --qemu-sipi --audio --overlay
	sleep 8
	DISPLAY=:0 daemon -f vncviewer 127.0.0.1:5913; sleep 3
	for w in $(DISPLAY=:0 xdotool search --name 'vm0-13' 2>/dev/null); do DISPLAY=:0 xdotool windowminimize $w; done
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
	dice "ripetizione $k: esito ${esito:-scaduto} dopo $(( $(date +%s) - t0 )) s ($S)"
	i=0; while pgrep -f "sh $B/strumenti/sorveglia-rete.sh" >/dev/null && [ $i -lt 300 ]; do sleep 3; i=$((i + 3)); done
	O=$(basename $S .txt | sed 's/sorveglia-rete-//')
	dice "riga d'avvio: $(grep -a "^- AVVIO $O" $D/esiti.md | sed 's/.*Windows: //' | cut -c1-200)"
	case "$esito" in
	ok)
		timeout 60 sshpass -f $PF ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 marietto@IP-WINDOWS-A \
		    'shutdown /s /t 3 /c "claude: esperimento riorganizzazione"' >/dev/null 2>&1
		if ! aspetta_uscita 300; then dice "shutdown non riuscito: quit QMP (overlay)"; qmp_quit; aspetta_uscita 60; fi
		;;
	guasto)
		dice "★ ripetizione $k: RETE GUASTA (kit gia' lanciato dal sorvegliante); quit QMP (overlay)"
		qmp_quit; aspetta_uscita 60
		;;
	*)
		dice "ripetizione $k: esito '${esito:-scaduto}': quit QMP e STOP"
		qemu_vivo && qmp_quit; aspetta_uscita 60; residuo; exit 4
		;;
	esac
	qemu_vivo && { dice "STOP: QEMU ancora vivo"; exit 4; }
	k=$((k + 1))
done
residuo
dice "fine esperimento: $N ripetizioni"
