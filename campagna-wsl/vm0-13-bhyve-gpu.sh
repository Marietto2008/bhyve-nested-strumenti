#!/bin/sh
# vm0-13-bhyve-gpu.sh -- Claude 04/11/2026. La VM Windows clone (vm0:13, Windows11-wsl2-freebsd.img) sotto bhyve
# NATIVO, SENZA nesting, con la RTX 2080 Ti (4/0/0..3) in passthrough e l'HDA come prima del nesting (utente 04/11:
# «Fai partire la vm Windows senza nesting ma con la gpu nvidia passata e la scheda audio come si faceva prima»).
# Modello: Backup_Script_Avvio/script-avvio-vm-2026-10-29/nested/12-Windows-11-nvidia-vm12-senza-nested, ma
# sull'immagine CLONE (l'originale Windows11.img della vm12 non si tocca). Derivato da vm0-13-wsl2-freebsd.sh.
# ⚠ Dopo una VM con passthrough NON si ricarica il vmm a caldo (reset secco dell'host il 18/10): solo riavvio.
# Gira come ROOT. Con --prova stampa il comando e NON avvia niente.
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
PROVA=0; NESTED=0; SOLOGPU=0; SOLOXHCI=0; SOLODEV=""; prossimo=""; SENZAMSIX=0; AHCIDIAG=0
for a in "$@"; do
	if [ "$prossimo" = dev ]; then SOLODEV=$a; prossimo=""; continue; fi
	case $a in
	--prova) PROVA=1;;
	--nested) NESTED=1;;		# 04/11: utente «Ora rimetti il nesting»
	--solo-gpu) SOLOGPU=1;;		# 04/11: bisezione, solo la funzione VGA 4/0/0
	--solo-xhci) SOLOXHCI=1;;	# 04/11 parere Opus 004 §4: solo l'xHCI 4/0/2 come funzione 0
	--solo-dev) prossimo=dev;;
	--senza-msix-orfana) SENZAMSIX=1;;	# 04/11 parere Opus 005 §4.2: bhyve diagnostico, la GPU usa l'MSI	# 04/11: un dispositivo qualunque B/S/F da solo come funzione 0
	--ahci-diag) AHCIDIAG=1;;	# 05/11 parere Astra 008 §5: bhyve diagnostico con l'anello AHCI
	*) echo "uso: $0 [--prova] [--nested] [--solo-gpu|--solo-xhci|--solo-dev B/S/F] [--senza-msix-orfana|--ahci-diag]"; exit 4;;
	esac
done
[ "$prossimo" = dev ] && { echo "--solo-dev vuole B/S/F"; exit 4; }
C=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/macchina-vm13.conf
BHYVE=/mnt/linuxulator2/vm/wsl2/fbsd/stage/current/sbin/bhyve
BHYVE_SHA=d393103a6f56885100fc63c0b8bc37921878e0bb3dc3af2a0b556fbd390e2955
UEFI=/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd
v() { sed -n "s/^$1=//p" "$C" | head -1; }
VM=$(v vm); [ "$VM" = vm0:13 ] || { echo "VM '$VM': solo vm0:13"; exit 4; }
if [ $SENZAMSIX = 1 ]; then
	BHYVE=/mnt/linuxulator2/vm/wsl2/fbsd/stage/diag-nomsix-20261104/sbin/bhyve
	BHYVE_SHA=2a268a39cc066512abccca806112c0763b649c363b211e7e214662e296fded2c
	export BHYVE_PASSTHRU_NO_ORPHAN_MSIX=1
fi
if [ $AHCIDIAG = 1 ]; then
	[ $SENZAMSIX = 1 ] && { echo "--ahci-diag e --senza-msix-orfana insieme: no"; exit 4; }
	BHYVE=/mnt/linuxulator2/vm/wsl2/fbsd/stage/diag-ahci-20261105/sbin/bhyve
	BHYVE_SHA=1275e60c67c7bd6d07210d0b29cf0761d4cda17b185f3140efdde9a955375fd9
	export BHYVE_AHCI_DIAG=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs/ahci-diag-$(date +%Y%m%d-%H%M%S).bin
fi
[ "$(sha256 -q "$BHYVE")" = "$BHYVE_SHA" ] || { echo "bhyve diverso da quello della serie"; exit 4; }
# una VM alla volta: niente in /dev/vmm e nessun processo bhyve
altre=$(ls /dev/vmm 2>/dev/null | tr '\n' ' ')
[ -z "$altre" ] || { echo "STOP: c'e' gia' una VM ($altre): la vm0:13 parte solo da sola"; exit 4; }
# pgrep -x bhyve NON basta: i binari della serie si chiamano anche bhyve-hlt-mirrorfix ecc.
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
for f in 0 1 2 3; do pciconf -l | grep -q "^ppt[0-9]*@pci0:4:0:$f:" || { echo "4/0/$f non e' su ppt"; exit 4; }; done
if [ -n "$SOLODEV" ]; then d=$(echo "$SOLODEV" | tr / :); pciconf -l | grep -q "^ppt[0-9]*@pci0:$d:" || { echo "$SOLODEV non e' su ppt"; exit 4; }; fi
REC=$(awk -F: '/^pcm[0-9]+:/ && /rec/ {sub("pcm","",$1); print "/dev/dsp" $1; exit}' /dev/sndstat); [ -n "$REC" ] || REC=/dev/null
set -- "$BHYVE" -S -c "$(v cpu)" -m "$(v memoria)" -w -H -A \
	$( [ $NESTED = 1 ] && echo "-o x86.nested_virt=true" ) \
	-s 0,hostbridge \
	-s 1,ahci-hd,"$IMG",bootindex=1 \
	$( if [ -n "$SOLODEV" ]; then echo "-s 8:0,passthru,$SOLODEV"; elif [ $SOLOXHCI = 1 ]; then echo "-s 8:0,passthru,4/0/2"; elif [ $SOLOGPU = 1 ]; then echo "-s 8:0,passthru,4/0/0"; else echo "-s 8:0,passthru,4/0/0 -s 8:1,passthru,4/0/1 -s 8:2,passthru,4/0/2 -s 8:3,passthru,4/0/3"; fi ) \
	-s 11,hda,play=/dev/dsp,rec="$REC" \
	-s 13,virtio-net,"$(v tap)" \
	-s 29,fbuf,tcp="$(v vnc)",w=1600,h=950 \
	-s 30,xhci,tablet \
	-s 31,lpc \
	-l bootrom,"$UEFI" \
	"$VM"
echo "vm0-13 (bhyve, nesting=$NESTED, solo_gpu=$SOLOGPU, solo_xhci=$SOLOXHCI, solo_dev=$SOLODEV, senza_msix=$SENZAMSIX, ahci_diag=${BHYVE_AHCI_DIAG:-no}, RTX 2080 Ti): immagine $IMG, nessun disco dati, rete $(v tap), VNC $(v vnc) (vncviewer localhost:13)"
[ $PROVA = 1 ] && { echo "PROVA, non avvio:"; echo "$@"; exit 0; }
# bhyve esce a ogni riavvio del sistema ospite: 0 = riavvio (si riparte), 1 spento, 2 arresto, 3 triplo errore,
# 4 errore (ci si ferma). L'istanza si distrugge solo DOPO l'uscita del NOSTRO bhyve.
while :; do
	"$@"; rc=$?
	bhyvectl --destroy --vm="$VM" >/dev/null 2>&1
	echo "vm0-13: bhyve uscito rc=$rc $(date '+%F %T')"
	[ $rc -eq 0 ] || exit $rc
	echo "vm0-13: riavvio del sistema ospite, riparto"
	sleep 2
done
