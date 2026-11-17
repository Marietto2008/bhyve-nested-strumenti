#!/bin/sh
# vm0-13-qemu.sh -- Claude 02/11/2026. CONFIGURAZIONE A: la stessa VM Windows clone (vm0:13) con QEMU e
# l'acceleratore bhyve con il nested (-accel bhyve,nested=on), invece di bhyve. Stessa immagine, stessi 8 vCPU e
# 32 GB, stesso MAC (00:a0:98:a1:73:65 -> stesso indirizzo DHCP), tap13, VNC 127.0.0.1:5913.
# MAI PROVATA PRIMA del 02/11: il QEMU nested aveva fatto girare solo i KUT.
#   - 02/11 (utente: «Non voglio snapshot, ti ho fatto clonare l'immagine originale [...] per far si che le modifiche
#     attecchiscano sulla copia per sempre»): si SCRIVE sul clone per difetto. --snapshot solo se chiesto; con lo snapshot
#     ogni avvio era il primo su q35 (driver e rilevamento rifatti e buttati via) e Windows restava sempre occupata.
#   - parte SOLO se non c'e' nessun'altra VM (stessa immagine e stesso nome Windows della vm0:13 sotto bhyve).
# Gira come ROOT. Con --prova stampa il comando e NON avvia niente.
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
PROVA=0; SNAP=off
# TRACCIA=1 di base (02/11): la rete virtio-net e' intermittente, ogni avvio fallito deve lasciare la sua traccia
SIPI=0; NICOPT=""; TRACCIA=1; AUDIO=0; GPU=0; CACHE=writeback; DIAGOSS=0; R1R3=0; OVERLAY=0; DIAGRESET=0; SIPIVECCHIO=0
for a in "$@"; do case $a in --prova) PROVA=1;; --scrivi) SNAP=off;; --snapshot) SNAP=on;; --qemu-sipi) SIPI=1;;
	--qemu-sipi-vecchio) SIPI=1; SIPIVECCHIO=1;;	# 15/11: il QEMU di prima (a259872f): un riavvio di Windows si BLOCCA (MTRR, AP nel firmware)
	--qemu-r1r3) SIPI=1; R1R3=1;;
	--qemu-r2) SIPI=1; R1R3=2;;	# 15/11 (Fable 046 §5 passo 2): R1+R3 + gestore di reset che chiama VM_RESET_INPLACE (serve il modulo R2)	# 14/11 (Fable 044 passo 1): qemu-sipi + R1 (AP in wait-for-SIPI al reset) + R3 (errori dei registri stampati)
	--diag-reset) DIAGRESET=1;;	# 15/11 (Fable 046 §3): debugcon 0x402 su file (console di OVMF, se build di debug) e nomi dei thread vCPU per DTrace
	--overlay) OVERLAY=1;;	# 14/11 (Fable 044 §4): disco su overlay qcow2 sopra l'immagine raw e copia delle variabili OVMF: l'immagine vera non si scrive
	--nic-noeventidx) NICOPT=",event_idx=off";;
	--trace-virtio) TRACCIA=1;;	# 02/11: eventi virtio/MSI-X dall'avvio in un file a parte (rete intermittente)
	--diag-hlt-userspace) export BHYVE_HLT_USERSPACE=1;;	# 03/11: SOLO controprova del vecchio modello (HLT atteso in QEMU)
	--diag-qemu-senza-fix-oss) DIAGOSS=1;;	# 03/11: SOLO controprova: QEMU f5902afb meno 813525873c (poll OSS)
	--diag-cache-none) CACHE=none;;	# 03/11: SOLO controprova (la rete bloccata dipendeva dal disco lento?), non per l'uso
	--gpu-nvidia) GPU=1;;	# 04/11: RTX 2080 Ti (4/0/0..3) in passthrough con bhyve-passthru, come 33-qemu-nvidia-ubuntu
	--vept-keep0) KEEP=0;;	# 05/11: SOLO controprova del panic LAPIC (rapporto 009): foglie ombra non conservate
	--audio) AUDIO=1;;		# 02/11: HDA di q35 (driver incluso in Windows) su /dev/dsp, come hda in B	# 02/11: prova diagnostica della ricezione virtio-net bloccata
	*) echo "uso: $0 [--prova] [--snapshot] [--qemu-sipi] [--qemu-sipi-vecchio] [--qemu-r1r3] [--qemu-r2] [--overlay] [--diag-reset] [--nic-noeventidx] [--trace-virtio] [--audio] [--gpu-nvidia] [--diag-cache-none] [--diag-hlt-userspace] [--diag-qemu-senza-fix-oss] [--vept-keep0]"; exit 4;; esac; done
C=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/macchina-vm13.conf
QEMU=/mnt/linuxulator2/vm/wsl2/fbsd/stage/current/bin/qemu-system-x86_64
QEMU_SHA=650a2bdec6f0fb61ec19066dcd13edd0b647267fd0cec2d0ce8974124b08859a
# --qemu-sipi (Claude 02/11): lo stesso QEMU + wait-for-SIPI (qemu-sipi 883658d899): con OVMF a piu' vCPU gli AP
# eseguivano il firmware dal vettore di reset fra INIT e SIPI (triple fault con nested, blocco con 32 GB)
if [ $SIPI = 1 ]; then
	QEMU=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/qemu-sipi/qemu-system-x86_64
	# 02/11 23:21: qemu-sipi 813525873c (poll OSS solo con arretrato: prima, a flusso audio aperto, il ciclo
	# principale girava a vuoto a ~270.000 ppoll/s su /dev/dsp sempre scrivibile). Il precedente era a572a673.
	# 02/11 23:59: + 4c34d01767 (tracce MSI-X: scartata/mascherata/inviata/maschera), sezione 7.2 di Opus.
	# 10/11: + 85e77202b1 (tracce msix_table_write e msix_reset, diagnosi Fable 020 §3.1, rete di Windows
	# con MSI-X mai programmata). Il binario precedente e' qemu-system-x86_64.f5902afb accanto.
	QEMU_SHA=a259872ffdd22e1096bf441ff29d3431519bd263e0c61252cf135e1d6a6b206e
	# 15/11 (Fable 050 §7 punto 4, OK dell'utente): --qemu-sipi = QEMU 952a4086 (R1 + R3 + reset del modulo, qemu-sipi
	# 3f516059c9), col modulo R2b: 20/20 riavvii e 3/3 system_reset con vCPU in L2. Il binario di prima resta con
	# --qemu-sipi-vecchio. Con un modulo senza VM_RESET_INPLACE 952a4086 stampa una riga e fa come prima.
	if [ $SIPIVECCHIO = 0 ]; then
		QEMU=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/qemu-sipi/qemu-system-x86_64.952a4086
		QEMU_SHA=952a4086e00b8ca1ab7583ec116609e9b529baf3aadf980bfcc501a6cadd3d52
	fi
fi
if [ $R1R3 = 1 ]; then
	# 14/11: qemu-sipi 85e77202b1 + R1/R3 (non ancora in un commit), compilato col sysroot
	# nested-work/sysroot-nested-kvm-d012c2ff (header del modulo caricato); rapporto 043, diagnosi 044
	QEMU=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/qemu-sipi/qemu-system-x86_64.41aba3ef
	QEMU_SHA=41aba3ef2b81fc3f3551abc40c97063e6db03fc713f5bb0f5dedb825dde3e19a
fi
if [ $R1R3 = 2 ]; then
	# 15/11: + R2 lato QEMU (bhyve_reset_kernel -> VM_RESET_INPLACE) e KGS_BASE solo contato; sysroot
	# nested-work/sysroot-nested-kvm-r2. Con un modulo senza la ioctl stampa una riga e fa come prima.
	QEMU=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/qemu-sipi/qemu-system-x86_64.952a4086
	QEMU_SHA=952a4086e00b8ca1ab7583ec116609e9b529baf3aadf980bfcc501a6cadd3d52
fi
if [ $DIAGOSS = 1 ]; then
	QEMU=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/diag/qemu-senza-fix-oss
	QEMU_SHA=1e76227ebb1036ea2bb78e797464b078c850075a380e146b16600ee26cfd741a
fi
PCBIOS=/mnt/linuxulator2/vm/wsl2/fbsd/qemu-nested/pc-bios
OVMF_CODE=/usr/local/share/qemu/edk2-x86_64-code.fd
OVMF_VARS=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/vm0-13-qemu-vars.fd
export TMPDIR=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/tmp	# il file dello snapshot (02/11: spostato fuori dal disco radice, quasi pieno)
v() { sed -n "s/^$1=//p" "$C" | head -1; }
[ "$(sha256 -q "$QEMU")" = "$QEMU_SHA" ] || { echo "QEMU diverso da quello approvato"; exit 4; }
# 02/11: se Windows si spegne da sola QEMU esce ma vm2 resta nel kernel: residuo SOLO se e' vm2 e nessun QEMU gira
if [ "$(ls /dev/vmm 2>/dev/null)" = vm2 ] && ! pgrep -f '/qemu-system-x86_64 ' >/dev/null; then
	[ $PROVA = 1 ] && echo "(residuo vm2 senza QEMU: verrebbe distrutto)" || { bhyvectl --destroy --vm=vm2 && echo "residuo vm2 distrutto"; }
fi
altre=$(ls /dev/vmm 2>/dev/null | tr '\n' ' ')
[ -z "$altre" ] || { echo "STOP: c'e' gia' una VM ($altre): la configurazione A parte solo da sola"; exit 4; }
ps -ax -o comm= | grep -qiE 'bhyve|qemu-system' && { echo "STOP: un processo bhyve/qemu e' vivo"; exit 4; }
disco() { geom disk list | awk -v id="$1" '/^Geom name: /{d=$NF} $1 == "ident:" && $2 == id && d {print d; exit}'; }
DI=$(disco "$(v disco_immagine_ident)")
[ -n "$DI" ] || { echo "disco dell'immagine assente"; exit 4; }
if [ $PROVA = 0 ]; then
	mount | grep -q " on /mnt/${DI}p2 " || { mkdir -p "/mnt/${DI}p2" && mount -t ufs "/dev/${DI}p2" "/mnt/${DI}p2"; } || { echo "mount di /dev/${DI}p2 non riuscito"; exit 4; }
fi
IMG=/mnt/${DI}p2/$(v immagine)
# 17/11 (utente): immagine di lavoro su ZFS se macchina-vm13.conf ha immagine_percorso; il G-DRIVE resta copia di sicurezza
IP=$(v immagine_percorso); if [ -n "$IP" ]; then [ -f "$IP" ] || { echo "manca l'immagine $IP"; exit 4; }; IMG=$IP; fi
[ -f "$IMG" ] || { echo "immagine assente: $IMG"; exit 4; }
# 8 vCPU come la vm0:13 sotto bhyve (cpu=sockets=1,cores=8,threads=1 in macchina-vm13.conf)
N=$(v cpu | sed -n 's/.*cores=\([0-9]*\).*/\1/p'); [ -n "$N" ] || N=8
# 14/11 --overlay (Fable 044 §4, riavvii di prova): a ogni avvio un overlay qcow2 NUOVO sopra l'immagine raw (aperta
# in sola lettura come backing) e una copia nuova delle variabili OVMF, entrambi datati e lasciati sul posto per
# l'ispezione dal ponte Ubuntu. Un overlay vale solo finche' l'immagine raw non viene riscritta.
DISCO="file=$IMG,format=raw"
if [ $OVERLAY = 1 ]; then
	[ $SNAP = off ] || { echo "--overlay e --snapshot insieme no"; exit 4; }
	OVD=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/overlay
	T=$(date +%Y%m%d-%H%M%S)
	OV=$OVD/vm0-13-overlay-$T.qcow2; OVV=$OVD/vm0-13-qemu-vars-$T.fd
	# 15/11: OVL_RIUSA=<overlay.qcow2> riprende un overlay esistente con la SUA copia delle variabili (stesso suffisso):
	# serve per un avvio a FREDDO su uno stato preparato prima (es. BCD cambiato, prova A della Fable 052)
	if [ -n "${OVL_RIUSA:-}" ]; then
		OV=$OVL_RIUSA; OVV=$OVD/vm0-13-qemu-vars-$(basename "$OV" .qcow2 | sed 's/^vm0-13-overlay-//').fd
		[ -f "$OV" ] && [ -f "$OVV" ] || { echo "OVL_RIUSA: manca $OV o $OVV"; exit 4; }
	elif [ $PROVA = 0 ]; then
		mkdir -p "$OVD" && [ ! -e "$OV" ] && [ ! -e "$OVV" ] || { echo "overlay: cartella o nomi non disponibili"; exit 4; }
		/usr/local/bin/qemu-img create -q -f qcow2 -b "$IMG" -F raw "$OV" || { echo "overlay non creato"; exit 4; }
		cp -p "$OVMF_VARS" "$OVV" || { echo "copia delle variabili OVMF non riuscita"; exit 4; }
	fi
	DISCO="file=$OV,format=qcow2"; OVMF_VARS=$OVV
	echo "overlay: $OV (backing $IMG, raw, sola lettura); variabili OVMF: $OVV"
fi
# 02/11 23:4x: cache=writeback come bhyve in B (ahci-hd senza direct = cache dell'host; i FLUSH dell'ospite
# diventano fdatasync). Con cache=none (O_DIRECT) ogni lettura andava al disco USB: preadv da 65-130 ms, ~70 IOPS
# saturi, e in Windows una creazione di processo costava 0,5-1,3 s (login SSH 4-11 s).
# 03/11: socket QMP per spegnere Windows con ACPI (system_powerdown) quando la rete non c'e' e per
# interrogare QEMU senza rete; uccidere QEMU staccherebbe la corrente al clone, che si scrive davvero.
set -- "$QEMU" -name vm0-13-qemu -L "$PCBIOS" \
	-machine q35,hpet=off -accel bhyve,nested=on -cpu max \
	-rtc base=localtime \
	-smp "$N",sockets=1,cores="$N",threads=1 -m "$(v memoria)" \
	-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
	-drive if=pflash,format=raw,file="$OVMF_VARS" \
	-drive "$DISCO",if=none,id=d0,cache=$CACHE,snapshot=$SNAP \
	-device ide-hd,drive=d0,bus=ide.0,bootindex=1 \
	-netdev tap,id=n0,ifname="$(v tap)",script=no,downscript=no \
	-device virtio-net-pci,netdev=n0,mac=00:a0:98:a1:73:65$NICOPT \
	-device VGA,xres=1600,yres=950 -display vnc=127.0.0.1:13 \
	-device qemu-xhci -device usb-tablet \
	-monitor none -qmp unix:/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock,server=on,wait=off -serial none
echo "vm0-13 (A, QEMU): immagine $IMG snapshot=$SNAP, $N vCPU, rete $(v tap), VNC 127.0.0.1:5913"
if [ $TRACCIA = 1 ]; then
	TF=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs/vm0-13-qemu-trace-$(date +%Y%m%d-%H%M%S).txt
	set -- "$@" -D "$TF" -trace enable=virtio_set_status -trace enable=virtio_queue_notify -trace enable=virtio_notify \
		-trace enable=msix_write_config -trace enable=virtio_pci_notify_write \
		-trace enable=msix_notify_unused -trace enable=msix_notify_masked -trace enable=msix_notify_send \
		-trace enable=msix_mask_update \
		-trace enable=msix_table_write -trace enable=msix_reset \
		-trace enable=pci_cfg_write -trace enable=pci_update_mappings_add -trace enable=pci_update_mappings_del \
		-d invalid_mem
	# 10/11 (diagnosi Fable 020 §3.1): scritture della tabella MSI-X, reset, scritture di configurazione PCI,
	# BAR che compaiono e scompaiono; -d invalid_mem: accessi MMIO rifiutati (la tabella vuole 4-8 byte)
	echo "traccia virtio: $TF"
fi
if [ $DIAGRESET = 1 ]; then
	DC=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs/vm0-13-debugcon-$(date +%Y%m%d-%H%M%S).txt
	set -- "$@" -name vm0-13-qemu,debug-threads=on -debugcon file:"$DC" -global isa-debugcon.iobase=0x402
	echo "diag-reset: debugcon $DC, thread vCPU con nome"
fi
if [ $AUDIO = 1 ]; then
	DSP=$(awk -F: '/^pcm[0-9]+:/ && /play/ {sub("pcm","",$1); print "/dev/dsp" $1; exit}' /dev/sndstat); [ -n "$DSP" ] || DSP=/dev/dsp
	set -- "$@" -audiodev oss,id=snd0,out.dev="$DSP",in.dev="$DSP" -device ich9-intel-hda -device hda-duplex,audiodev=snd0
	echo "audio: $DSP"
fi
if [ $GPU = 1 ]; then
	# 04/11 (utente: la VM deve avere la 2080 Ti). Le 4 funzioni devono essere su ppt (pptdevs del loader.conf).
	# ⚠ Dopo una VM con passthrough NON si ricarica il vmm a caldo (reset secco dell'host il 18/10): solo riavvio.
	"$QEMU" -device help 2>/dev/null | grep -q bhyve-passthru || { echo "questo QEMU non ha bhyve-passthru"; exit 4; }
	manca=""
	for f in 0 1 2 3; do pciconf -l | grep -q "^ppt[0-9]*@pci0:4:0:$f:" || manca="$manca 4/0/$f"; done
	[ -z "$manca" ] || { echo "funzioni NVIDIA non su ppt:$manca"; exit 4; }
	# Rattoppo MSI-X (33-qemu-nvidia-ubuntu): la capability PCIe a 0x78 ha il puntatore 0x79 a 0 e la MSI-X a 0xC8
	# resta orfana; bhyve-passthru legge la configurazione FISICA e senza MSI-X il driver del guest non ha IRQ.
	if [ $PROVA = 0 ]; then
		prima=$(pciconf -rb pci0:4:0:0 0x79 2>/dev/null)
		pciconf -wb pci0:4:0:0 0x79 0xc8 2>/dev/null || { echo "rattoppo MSI-X non scritto"; exit 4; }
		echo "GPU: 0x79 $prima -> $(pciconf -rb pci0:4:0:0 0x79 2>/dev/null)"
	fi
	# la VGA emulata resta la primaria (slot basso): la RTX va allo slot 0x08
	set -- "$@" -device bhyve-passthru,host=4/0/0,multifunction=on,addr=0x08.0 \
		-device bhyve-passthru,host=4/0/1,addr=0x08.1 -device bhyve-passthru,host=4/0/2,addr=0x08.2 \
		-device bhyve-passthru,host=4/0/3,addr=0x08.3
	echo "GPU: RTX 2080 Ti 4/0/0..3 allo slot 0x08"
fi
[ $PROVA = 1 ] && { echo "PROVA, non avvio:"; echo "$@"; exit 0; }
# 02/11: Windows+Hyper-V va lanciato con la EPT ombra in modalita' keep (collaudata, #81): si fissa alla CREAZIONE
# dei vCPU. Con vept_keep=0 ogni ingresso in L2 butta via le foglie: 250.000 INVEPT e fault EPT02 al secondo, Windows
# ferma e QEMU al 300%; con 1: SSH dopo 64 s, QEMU 70-130%.
sysctl hw.vmm.vmx.vept_keep=${KEEP:-1} >/dev/null || { echo "vept_keep=${KEEP:-1} non impostabile"; exit 4; }
echo "vept_keep=$(sysctl -n hw.vmm.vmx.vept_keep)"
# 16/11 (diagnosi 059/061): validazione al rientro in L2 della radice shadow conservata da B1, impostata PRIMA della
# creazione dei vCPU. 2 = correzione (validazione solo al rientro; di base dal 16/11 sera, 6 giri amplificati su 6
# puliti), 1 = misura (e protegge), 0 = solo prove (buco di B1 aperto). Solo se il modulo caricato ha il sysctl.
if sysctl -n hw.vmm.vmx.vept_keep_rientro >/dev/null 2>&1; then
	sysctl hw.vmm.vmx.vept_keep_rientro=${RIENTRO:-2} >/dev/null || { echo "vept_keep_rientro=${RIENTRO:-2} non impostabile"; exit 4; }
	echo "vept_keep_rientro=$(sysctl -n hw.vmm.vmx.vept_keep_rientro)"
fi
# 17/11 (Fable 067 par. 5.3.4): registratore delle hypercall azzerato prima di ogni avvio di Windows
if sysctl -n hw.vmm.vmx.nested_hcall_reg >/dev/null 2>&1; then
	sysctl hw.vmm.vmx.nested_hcall_azzera=1 >/dev/null && echo "registratore hypercall azzerato (reg=$(sysctl -n hw.vmm.vmx.nested_hcall_reg) eptp=$(sysctl -n hw.vmm.vmx.nested_hcall_eptp))"
fi
# 17/11 (richiesta dell'utente): sorvegliante della rete, parte un attimo prima di QEMU e segue l'avvio di Windows:
# hypercall ogni 5 s, e se virtio-net accende MSI-X senza smascherare vettori lancia da solo rete-guasta-kit.sh a VM viva
# 17/11 (Fable 069 par. 4.4): condizioni di questo avvio, per la riga che il sorvegliante scrive in esiti.md con l'esito
ULT=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-bhyve/vm0-13-ultima-sessione.txt
CAR=$(sysctl -n hw.vmm.vmx.caricato 2>/dev/null || echo 0)
# modulo caricato all'avvio dell'host, prima che l'orologio sia impostato: caricato vale pochi secondi -> ora d'avvio
[ "$CAR" != 0 ] && [ "$CAR" -lt 1000000000 ] && CAR=$(sysctl -n kern.boottime | sed 's/^{ sec = \([0-9]*\),.*/\1/') && CAR_NOTA=" (all'avvio dell'host)"
VMC=$(sysctl -n hw.vmm.vmx.vm_create 2>/dev/null || echo ?)
MODF=$(dirname "$(sysctl -n kern.bootfile)")/vmm-restore.ko
COND="modulo $(sha256 -q "$MODF" | cut -c1-8)"
[ "$CAR" != 0 ] && COND="$COND caricato da $(( ($(date +%s) - CAR) / 60 )) min${CAR_NOTA:-}" || COND="$COND (ora di caricamento ignota)"
COND="$COND; VM create dal caricamento $VMC$([ "$VMC" = 0 ] && echo ' (PRIMA VM)')"
COND="$COND; sessione precedente: $(tail -1 $ULT 2>/dev/null || echo 'ignota')"
COND="$COND; QEMU $(sha256 -q "$QEMU" | cut -c1-8); disco $([ $OVERLAY = 1 ] && echo "overlay $(basename "${OV:-?}")" || echo vero), $(case "$IMG" in /mnt/linuxulator2/*) echo ZFS;; *) echo G-DRIVE;; esac) $IMG"
echo "condizioni: $COND"
echo "$(date '+%d/%m %H:%M:%S') avvio in corso (se resta l'ultima riga, la sessione non e' finita dal lanciatore)" >> $ULT
export COND
if [ $TRACCIA = 1 ] && [ -n "${TF:-}" ]; then
	daemon -f sh /mnt/linuxulator2/vm/confronto-kvm-bhyve/strumenti/sorveglia-rete.sh "$TF"
	echo "sorvegliante della rete avviato (dati-bhyve/sorveglia-rete-*.txt)"
fi
# 15/11 (Fable 052 §3): niente exec; a fine sessione gli invarianti del modulo finiscono in esiti.md (un contatore non
# letto prima dello scaricamento e' perso, lezione del 048)
"$@"
rc=$?
echo "$(date '+%d/%m %H:%M:%S') QEMU uscito rc=$rc$([ $rc = 0 ] && echo ' (shutdown ACPI o quit QMP)' || echo ' (SIGTERM o errore)')" >> $ULT
sh /mnt/linuxulator2/vm/confronto-kvm-bhyve/strumenti/salva-contatori.sh "fine sessione vm0:13 (QEMU rc=$rc)"
exit $rc
