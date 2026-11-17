#!/bin/sh
# sorveglia-rete.sh -- claude 17/11/2026 (richiesta dell'utente): cattura AUTOMATICA del guasto «Windows senza rete».
# Parte dal lanciatore vm0-13-qemu.sh un attimo PRIMA di QEMU e segue l'avvio fin dal primo secondo:
#   - ogni 5 s per i primi 5 minuti fotografa i contatori del registratore delle hypercall (sequenza nel tempo di cio'
#     che la radice chiede a Hyper-V prima e durante la programmazione degli interrupt);
#   - legge la traccia QEMU: quando virtio-net accende MSI-X («enabled 1») aspetta ATTESA s; se nessun vettore e' stato
#     smascherato («maschera 1->0») e' il guasto -> lancia rete-guasta-kit.sh A VM VIVA e lo scrive in esiti.md;
#   - se la rete parte salva codici e anello dell'avvio buono (riferimento) e finisce;
#   - se virtio-net non accende MSI-X entro MAX s lancia il kit lo stesso (guasto di altra forma).
# Solo letture (QMP, sysctl, traccia): non spegne e non tocca nulla. Finisce da solo quando QEMU esce.
#   sh sorveglia-rete.sh <file della traccia QEMU>      (come root: la traccia e la presa QMP sono di root)
#   SOLO_PROVA=1 ATTESA=2 sh sorveglia-rete.sh <traccia vecchia>   collaudo: rileva e scrive solo nel suo registro
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
TF=${1:-}
ATTESA=${ATTESA:-30}		# secondi da «enabled 1» senza smascheramenti per dire «guasto»
MAX=${MAX:-900}			# secondi massimi di sorveglianza
B=/mnt/linuxulator2/vm/confronto-kvm-bhyve
D=$B/dati-bhyve
ORA=$(date +%Y%m%d-%H%M%S)
LOG=$D/sorveglia-rete-$ORA.txt
Q=/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock
[ -n "$TF" ] || { echo "uso: $0 <traccia QEMU>"; exit 4; }
dice() { echo "$(date '+%H:%M:%S') $*" >> $LOG; }
hcall() { sysctl -n hw.vmm.vmx.nested_hcall_codici 2>/dev/null | tr ' ' '\n' | grep -E '^0x7[cde]:|^0x11:|^0x49:|^oltre:' | tr '\n' ' '; }
qemu_vivo() { pgrep -f '/qemu-system-x86_64.* -name vm0-13-qemu' >/dev/null 2>&1; }
conta() { n=$(grep -a -c "$1" "$TF" 2>/dev/null); echo "${n:-0}"; }

dice "inizio: traccia $TF, attesa ${ATTESA}s, massimo ${MAX}s, registratore hypercall $(sysctl -n hw.vmm.vmx.nested_hcall_reg 2>/dev/null || echo assente)"
t0=$(date +%s)
# QEMU parte subito dopo: si aspetta che crei la traccia (al massimo 60 s)
i=0; while [ ! -f "$TF" ] && [ $i -lt 60 ]; do sleep 1; i=$((i + 1)); done
[ -f "$TF" ] || { dice "la traccia non e' comparsa in 60 s: fine"; exit 0; }
t_en=0; ultima_foto=0
while :; do
	sleep 2
	ora=$(date +%s); dt=$((ora - t0))
	if ! qemu_vivo; then dice "QEMU uscito (dopo ${dt}s): fine"; exit 0; fi
	if [ $dt -le 300 ] && [ $((dt - ultima_foto)) -ge 5 ]; then
		ultima_foto=$dt
		dice "t+${dt}s hcall: $(hcall)"
	fi
	en=$(conta 'msix_write_config dev virtio-net-pci enabled 1')
	sm=$(conta 'msix_mask_update dev virtio-net-pci.*1->0')
	if [ "$en" -gt 0 ] && [ $t_en = 0 ]; then
		t_en=$ora
		dice "t+${dt}s virtio-net accende MSI-X; tabella: $(grep -a 'msix_table_write dev virtio-net-pci tabella +0x[08] ' "$TF" | head -2 | sed 's/.*<- //; s/ (.*//' | tr '\n' ' ')"
	fi
	if [ "$sm" -gt 0 ]; then
		dice "t+${dt}s RETE OK: $sm vettori smascherati; hcall: $(hcall)"
		# 069 par. 4.4: arresto precedente secondo Windows (Kernel-Power 41 in questo avvio = il precedente fu brusco)
		[ "${SOLO_PROVA:-0}" = 1 ] && { dice "SOLO_PROVA: niente riga in esiti"; exit 0; }
		# 071 par. 2: anche tipo di avvio (27) e hive riorganizzati (KG15, manutenzione settimanale)
		avw=$(timeout 240 sh $B/strumenti/avvio-windows.sh 2>/dev/null)	# SSH di Windows sale dopo la rete
		echo "- AVVIO $ORA: ${COND:-condizioni ignote}; Windows: ${avw:-registro eventi non letto}; RETE OK ($sm vettori, t+${dt}s); 0x7c $(sysctl -n hw.vmm.vmx.nested_hcall_codici 2>/dev/null | tr ' ' '\n' | grep '^0x7c:' | cut -d: -f2)" >> $D/esiti.md
		sysctl -n hw.vmm.vmx.nested_hcall_codici > $D/sorveglia-rete-$ORA-codici.txt 2>/dev/null
		sysctl -n hw.vmm.vmx.nested_hcall_anello > $D/sorveglia-rete-$ORA-anello.txt 2>/dev/null
		exit 0
	fi
	guasto=""
	if [ $t_en != 0 ] && [ $((ora - t_en)) -ge $ATTESA ]; then
		guasto="virtio-net con MSI-X acceso da $((ora - t_en)) s e nessun vettore smascherato ($(conta 'msix_notify_masked dev virtio-net') notify_masked)"
	elif [ $t_en = 0 ] && [ $dt -ge $MAX ]; then
		guasto="virtio-net non ha acceso MSI-X in ${MAX} s"
	fi
	if [ -n "$guasto" ]; then
		dice "★ GUASTO RILEVATO: $guasto"
		if [ "${SOLO_PROVA:-0}" = 1 ]; then dice "SOLO_PROVA: niente kit, niente esiti, niente avviso"; exit 0; fi
		echo "- ★★★ $(date '+%d/%m %H:%M:%S') RETE GUASTA RILEVATA AUTOMATICAMENTE (sorveglia-rete.sh, $LOG): $guasto; kit lanciato a VM viva" >> $D/esiti.md
		echo "- AVVIO $ORA: ${COND:-condizioni ignote}; RETE GUASTA (vedi la riga sopra; tipo di avvio e KG15 da leggere col registro eventi dopo il riavvio)" >> $D/esiti.md
		sh $B/strumenti/rete-guasta-kit.sh >> $LOG 2>&1
		dice "kit finito (cartella nelle righe sopra); hcall: $(hcall)"
		# avviso sul desktop dell'utente, se c'e' una sessione X
		su -l marietto -c "DISPLAY=:0 notify-send -u critical 'vm0:13: rete di Windows GUASTA' 'Dati raccolti da sorveglia-rete.sh: non spegnere Windows prima di averli guardati'" >/dev/null 2>&1
		exit 0
	fi
done
