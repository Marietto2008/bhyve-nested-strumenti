#!/bin/sh
# vm0-12-wsl.sh -- Claude 01/11/2026. Definizione della VM Windows 11 (Hyper-V + WSL2) per la campagna sullo stadio 10.
# Deriva da freebsd-nested/tools/nested/12-Windows-11-vm12-senza-gpu (serie 12/12 del 20 e 22/10), con le STESSE
# periferiche, tranne:
#   - niente devctl/kldload nvidia-modeset (la 2080 Ti e' gia' su ppt da pptdevs), niente confronto del modulo con
#     stage/current (l'identita' dello stadio 10 la verifica run-wsl-corsa.sh), niente setxkbmap/vncviewer;
#   - il framebuffer VNC NON aspetta un client (niente `wait`) e ascolta solo in locale: la corsa gira staccata.
# Gira come ROOT (sudo -n sh, dalla riga guardata di run-wsl-corsa.sh) e finisce con `exec bhyve`: il figlio di sudo e'
# bhyve stesso. Legge i dati della macchina da macchina.conf; il bhyve e' quello della serie, verificato per sha.
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
C=/mnt/linuxulator2/vm/nested-work/campagna-wsl/macchina.conf
BHYVE=/mnt/linuxulator2/vm/nested-work/stage/current/sbin/bhyve
BHYVE_SHA=d393103a6f56885100fc63c0b8bc37921878e0bb3dc3af2a0b556fbd390e2955
UEFI=/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd
v() { sed -n "s/^$1=//p" "$C" | head -1; }
VM=$(v vm); [ "$VM" = vm0:12 ] || { echo "VM '$VM': solo vm0:12"; exit 4; }
[ "$(sha256 -q "$BHYVE")" = "$BHYVE_SHA" ] || { echo "bhyve diverso da quello della serie"; exit 4; }
disco() { geom disk list | awk -v id="$1" '/^Geom name: /{d=$NF} $1 == "ident:" && $2 == id && d {print d; exit}'; }
DI=$(disco "$(v disco_immagine_ident)"); DD=$(disco "$(v disco_dati_ident)")
[ -n "$DI" ] && [ -n "$DD" ] || { echo "dischi assenti (immagine '$DI', dati '$DD')"; exit 4; }
mount | grep -q " on /mnt/${DI}p2 " || { mkdir -p "/mnt/${DI}p2" && mount -t ufs "/dev/${DI}p2" "/mnt/${DI}p2"; } || { echo "mount di /dev/${DI}p2 non riuscito"; exit 4; }
IMG=/mnt/${DI}p2/$(v immagine)
[ -f "$IMG" ] || { echo "immagine assente: $IMG"; exit 4; }
# l'ingresso audio: il primo dispositivo che DICHIARA di saper registrare (memoria: rec=/dev/dsp fa scattare la assert)
REC=$(awk -F: '/^pcm[0-9]+:/ && /rec/ {sub("pcm","",$1); print "/dev/dsp" $1; exit}' /dev/sndstat); [ -n "$REC" ] || REC=/dev/null
echo "vm0-12-wsl: immagine $IMG, dati /dev/$DD, rec $REC, bhyve $BHYVE"
exec "$BHYVE" -S -c "$(v cpu)" -m "$(v memoria)" -w -H -A \
	-o x86.nested_virt=true \
	-s 0,hostbridge \
	-s 1,ahci-hd,"$IMG",bootindex=1 \
	-s 2,ahci-hd,/dev/"$DD" \
	-s 11,hda,play=/dev/dsp,rec="$REC" \
	-s 13,virtio-net,"$(v tap)" \
	-s 29,fbuf,tcp="$(v vnc)",w=1600,h=950 \
	-s 30,xhci,tablet \
	-s 31,lpc \
	-l bootrom,"$UEFI" \
	"$VM"
