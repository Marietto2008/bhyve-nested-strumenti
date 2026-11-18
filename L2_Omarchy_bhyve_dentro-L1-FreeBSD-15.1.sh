#!/bin/sh
# avvia-omarchy.sh -- Claude 06/11/2026. Avvia Omarchy (Arch Linux + Hyprland) con bhyve, sull'host o dentro
# l'L1 FreeBSD 15.1 (dove diventa la VM annidata L2). Da eseguire come root.
#
#   sh avvia-omarchy.sh             avvio normale dal disco
#   sh avvia-omarchy.sh --installa  avvio dalla ISO di omarchy (installazione); al primo riavvio del sistema
#                                   ospite la ISO viene tolta e si riparte dal disco
#
# Schermo: VNC su $VNC (dentro l'L1, predefinito 0.0.0.0:5900 = raggiungibile all'indirizzo dell'L1, porta 5900).
# Rete: virtio-net su $TAP (dentro l'L1 i tap0..tap20 sono gia' nel bridge0 con em0: la VM prende l'indirizzo dal
# DHCP della rete di casa).
# Nota: Hyprland vuole l'accelerazione grafica; con il solo framebuffer di bhyve il desktop potrebbe non partire
# o andare piano. Il sistema e la console funzionano comunque.
#
# Immagine: Omarchy installato il 05/10/2026 (LUKS2 + btrfs, bootloader limine con caricatore UEFI in
# EFI/BOOT/BOOTX64.EFI; no-kvmclock gia' in limine.conf). All'avvio chiede la passphrase LUKS nel VNC.
# File sparso: 200 GB apparenti, occupa solo quanto scritto; cresce con l'uso (controllare con du).
#
# Ogni impostazione si puo' cambiare dall'ambiente, per esempio:
#   TAP=tap16 VNC=127.0.0.1:5916 MEM=16G sh avvia-omarchy.sh
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
: "${IMG:=$DIR/linux-ai-omarchy.img}"
: "${VARS:=$DIR/linux-ai-omarchy-VARS.fd}"
: "${ISO:=$DIR/omarchy-4.0.4.iso}"
: "${CODE:=/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd}"
: "${BHYVE:=/usr/sbin/bhyve}"
: "${TAP:=tap1}"
: "${VNC:=0.0.0.0:5900}"
: "${CPU:=4}"
: "${MEM:=8G}"
: "${NOME:=omarchy}"

CD=""
case "${1:-}" in
--installa) CD="-s 3,ahci-cd,$ISO,bootindex=1" ;;
"") ;;
*) echo "uso: $0 [--installa]"; exit 4 ;;
esac

[ "$(id -u)" = 0 ] || { echo "va eseguito come root"; exit 4; }
for f in "$IMG" "$VARS" "$CODE" "$BHYVE"; do
	[ -e "$f" ] || { echo "manca: $f"; exit 4; }
done
[ -z "$CD" ] || [ -e "$ISO" ] || { echo "manca la ISO: $ISO"; exit 4; }
[ -e "/dev/vmm/$NOME" ] && { echo "la VM $NOME esiste gia' (bhyvectl --destroy --vm=$NOME se e' un residuo)"; exit 4; }
kldstat -q -m vmm || kldload vmm || { echo "vmm non caricabile (manca VMX? nell'L1 serve la nidificazione dell'host)"; exit 4; }
ifconfig "$TAP" >/dev/null 2>&1 || { echo "manca l'interfaccia $TAP"; exit 4; }

echo "omarchy: immagine $IMG, $CPU vCPU, $MEM, rete $TAP, VNC $VNC${CD:+, avvio dalla ISO}"
# bhyve esce a ogni riavvio del sistema ospite: 0 = riavvio (si riparte), 1 spento, 2 arresto, 3 triplo
# errore, 4 errore. L'istanza si distrugge sempre dopo l'uscita.
while :; do
	"$BHYVE" -c "$CPU" -m "$MEM" -w -H -A \
		-s 0,hostbridge \
		$CD \
		-s 4,virtio-blk,"$IMG" \
		-s 5,virtio-net,"$TAP" \
		-s 29,fbuf,tcp="$VNC",w=1600,h=900 \
		-s 30,xhci,tablet \
		-s 31,lpc \
		-l bootrom,"$CODE","$VARS" \
		"$NOME"
	rc=$?
	bhyvectl --destroy --vm="$NOME" >/dev/null 2>&1
	echo "omarchy: bhyve uscito rc=$rc $(date '+%F %T')"
	[ $rc -eq 0 ] || exit $rc
	[ -n "$CD" ] && { echo "omarchy: riavvio dopo l'installazione, tolgo la ISO"; CD=""; }
	sleep 2
done
