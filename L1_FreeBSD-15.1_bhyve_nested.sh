#!/bin/sh
# L1_FreeBSD-15.1_bhyve_nested.sh -- Claude 07/11/2026. Avvia sull'host la VM FreeBSD 15.1 come L1 annidato (con bhyve
# esposto al suo interno: x86.nested_virt=true), cosi' dentro di lei si possono avviare VM L2 (Omarchy).
# Da lanciare come marietto (usa sudo -n per le parti da root).
#
#   sh L1_FreeBSD-15.1_bhyve_nested.sh            avvia l'L1 (seriale + bhyve + finestra VNC)
#   sh L1_FreeBSD-15.1_bhyve_nested.sh --spegni   spegnimento pulito (tasto ACPI, poi distrugge l'istanza)
#   sh L1_FreeBSD-15.1_bhyve_nested.sh --stato    dice se gira
#
# Schermo: VNC 127.0.0.1:5915 (si apre da solo). Rete: e1000 su tap15 (nell'L1 e' em0), IP IP-LAN (DHCP).
# Seriale: /dev/nmdm15A per bhyve; il lato B e' letto in sottofondo e scritto in seriale-<data>.log.
# Registri: /mnt/linuxulator2/vm/nested-work/l1/{bhyve,seriale}-<data>.log
# Se l'L1 si riavvia da dentro, bhyve esce con 0 e lo script lo riparte; si ferma con spegnimento/arresto.
#
# Requisiti: modulo vmm dell'host con la nidificazione (vmm-restore.ko) caricato; bhyve della serie nested.
# Dentro l'L1: L2 Omarchy con  sudo sh /vm/omarchy/avvia-omarchy.sh  (VNC IP-LAN:5900).
set -u
NOME=l1fbsd15
#IMG=/mnt/da0p2/Backup/FreeBSD/IMG/2500-BMV-233-GiB-GPU-PassThru-FreeBSD-15p9-nested.img
IMG=/mnt/da0p2/bhyve/img/FreeBSD/2500-BMV-233-GiB-GPU-PassThru-FreeBSD-15p9-nested.img
BHYVE=/mnt/linuxulator2/vm/wsl2/fbsd/stage/current/sbin/bhyve
BHYVE_SHA=d393103a6f56885100fc63c0b8bc37921878e0bb3dc3af2a0b556fbd390e2955
CODE=/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd
TAP=tap15
VNC=127.0.0.1:5915
CPU=8
MEM=16G
REG=/mnt/linuxulator2/vm/nested-work/l1

# bhyve si rinomina in "bhyve: <nome>"; prima di farlo ha la riga di comando intera
pid_bhyve() { pgrep -f "bhyve(: | .* )$NOME( |\$)" | head -1; }

case "${1:-}" in
--stato)
	if [ -n "$(pid_bhyve)" ]; then echo "$NOME gira (bhyve pid $(pid_bhyve))"
	elif [ -e /dev/vmm/$NOME ]; then echo "$NOME spenta, ma e' rimasta l'istanza /dev/vmm/$NOME (la ripulisce il prossimo avvio)"
	else echo "$NOME spenta"; fi
	exit 0 ;;
--spegni)
	[ -n "$(pid_bhyve)" ] || { echo "$NOME non gira"; exit 0; }
	# prima il ciclo che la ripartirebbe, poi il tasto ACPI
	for p in $(pgrep -f "L1_FreeBSD-15.1_bhyve_nested.sh --ciclo"); do sudo -n kill "$p"; done
	p=$(pid_bhyve); [ -n "$p" ] && sudo -n kill -TERM "$p"
	echo "spegnimento ACPI inviato, attendo (max 180 s)..."
	T0=$(date +%s)
	while [ -n "$(pid_bhyve)" ] && [ $(( $(date +%s) - T0 )) -lt 180 ]; do sleep 2; done
	[ -n "$(pid_bhyve)" ] && echo "ATTENZIONE: bhyve ancora vivo dopo 180 s (pid $(pid_bhyve)); non lo forzo"
	[ -z "$(pid_bhyve)" ] && sudo -n bhyvectl --destroy --vm=$NOME 2>/dev/null
	[ -e /dev/vmm/$NOME ] && echo "istanza ancora presente" || echo "$NOME spenta"
	exit 0 ;;
--ciclo)
	# interno: gira come root sotto daemon(8); riparte bhyve ai riavvii dell'ospite
	LOG=$2
	while :; do
		"$BHYVE" -S -c $CPU -m $MEM -w -H -A -o x86.nested_virt=true \
			-s 0,hostbridge \
			-s 3,virtio-blk,"$IMG" \
			-s 5,e1000,$TAP \
			-s 29,fbuf,tcp=$VNC,w=1600,h=950 \
			-s 30,xhci,tablet \
			-s 31,lpc \
			-l com1,/dev/nmdm15A \
			-l bootrom,"$CODE" \
			$NOME
		rc=$?
		bhyvectl --destroy --vm=$NOME >/dev/null 2>&1
		echo "$(date '+%F %T') bhyve uscito rc=$rc (0 riavvio, 1 spento, 2 arresto, 3 triplo errore, 4 errore)" >> "$LOG"
		[ $rc -eq 0 ] || exit $rc
		sleep 2
	done ;;
"") ;;
*) echo "uso: $0 [--spegni | --stato]"; exit 4 ;;
esac

# ---- controlli ----
sudo -n true 2>/dev/null || { echo "serve sudo non interattivo"; exit 4; }
[ -n "$(pid_bhyve)" ] && { echo "$NOME gira gia' (per spegnerla: $0 --spegni)"; exit 4; }
if [ -e /dev/vmm/$NOME ]; then
	echo "istanza residua /dev/vmm/$NOME senza bhyve (ospite spento da dentro): la distruggo"
	sudo -n bhyvectl --destroy --vm=$NOME || { echo "distruzione fallita"; exit 4; }
fi
kldstat -q -n vmm-restore.ko || { echo "manca il modulo vmm con la nidificazione (vmm-restore.ko)"; exit 4; }
[ -f "$IMG" ] || { echo "manca l'immagine: $IMG (disco da0p2 montato?)"; exit 4; }
[ "$(sha256 -q "$BHYVE")" = "$BHYVE_SHA" ] || { echo "bhyve diverso da quello atteso: $BHYVE"; exit 4; }
ifconfig $TAP >/dev/null 2>&1 || { echo "manca l'interfaccia $TAP"; exit 4; }
SE=$(readlink -f "$0")

TS=$(date +%Y%m%d-%H%M%S)
# ---- seriale: un solo lettore sul lato B (due lettori si dividono i byte) ----
if fstat /dev/nmdm15B 2>/dev/null | grep -q nmdm15B || sudo -n fstat /dev/nmdm15B 2>/dev/null | grep -q nmdm15B; then
	echo "seriale: lettore gia' presente su /dev/nmdm15B"
else
	sudo -n daemon -o "$REG/seriale-$TS.log" /bin/sh -c 'exec < /dev/nmdm15B; stty raw -echo; exec cat'
	echo "seriale: $REG/seriale-$TS.log"
fi

# ---- bhyve ----
sudo -n daemon -o "$REG/bhyve-$TS.log" /bin/sh "$SE" --ciclo "$REG/bhyve-$TS.log"
echo "bhyve: $REG/bhyve-$TS.log"
T0=$(date +%s)
until nc -z 127.0.0.1 ${VNC##*:} 2>/dev/null || [ $(( $(date +%s) - T0 )) -gt 60 ]; do sleep 1; done
if nc -z 127.0.0.1 ${VNC##*:} 2>/dev/null; then
	DISPLAY=${DISPLAY:-:0} daemon -f vncviewer $VNC
	echo "$NOME avviata: VNC $VNC, SSH marietto@IP-LAN fra circa 30 s"
else
	echo "ERRORE: il VNC non risponde dopo 60 s; vedi $REG/bhyve-$TS.log"; exit 1
fi
