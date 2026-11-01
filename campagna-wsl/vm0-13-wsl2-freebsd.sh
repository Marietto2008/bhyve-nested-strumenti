#!/bin/sh
# vm0-13-wsl2-freebsd.sh -- Claude 01/11/2026. Definizione della VM Windows CLONE per WSL2-FreeBSD (vm0:13).
# Deriva da vm0-12-wsl.sh con le STESSE periferiche, tranne:
#   - immagine clonata Windows11-wsl2-freebsd.img; NESSUN disco dati (il WD Elements e' solo della vm0:12);
#   - tap13 e VNC 127.0.0.1:5913;
#   - parte SOLO se non c'e' nessun'altra VM: la vm0:12 ha lo stesso nome Windows e usa lo stesso disco USB.
# Gira come ROOT e finisce con `exec bhyve`. Con --prova stampa il comando e NON avvia niente.
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
PROVA=0; [ "${1:-}" = --prova ] && PROVA=1
C=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/macchina-vm13.conf
BHYVE=/mnt/linuxulator2/vm/wsl2/fbsd/stage/current/sbin/bhyve
BHYVE_SHA=d393103a6f56885100fc63c0b8bc37921878e0bb3dc3af2a0b556fbd390e2955
UEFI=/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd
v() { sed -n "s/^$1=//p" "$C" | head -1; }
VM=$(v vm); [ "$VM" = vm0:13 ] || { echo "VM '$VM': solo vm0:13"; exit 4; }
[ "$(sha256 -q "$BHYVE")" = "$BHYVE_SHA" ] || { echo "bhyve diverso da quello della serie"; exit 4; }
# una VM alla volta: niente in /dev/vmm e nessun processo bhyve
altre=$(ls /dev/vmm 2>/dev/null | tr '\n' ' ')
[ -z "$altre" ] || { echo "STOP: c'e' gia' una VM ($altre): la vm0:13 parte solo da sola"; exit 4; }
pgrep -x bhyve >/dev/null && { echo "STOP: un processo bhyve e' vivo"; exit 4; }
disco() { geom disk list | awk -v id="$1" '/^Geom name: /{d=$NF} $1 == "ident:" && $2 == id && d {print d; exit}'; }
DI=$(disco "$(v disco_immagine_ident)")
[ -n "$DI" ] || { echo "disco dell'immagine assente"; exit 4; }
if [ $PROVA = 0 ]; then
	mount | grep -q " on /mnt/${DI}p2 " || { mkdir -p "/mnt/${DI}p2" && mount -t ufs "/dev/${DI}p2" "/mnt/${DI}p2"; } || { echo "mount di /dev/${DI}p2 non riuscito"; exit 4; }
fi
IMG=/mnt/${DI}p2/$(v immagine)
[ -f "$IMG" ] || { echo "immagine assente: $IMG"; exit 4; }
REC=$(awk -F: '/^pcm[0-9]+:/ && /rec/ {sub("pcm","",$1); print "/dev/dsp" $1; exit}' /dev/sndstat); [ -n "$REC" ] || REC=/dev/null
set -- "$BHYVE" -S -c "$(v cpu)" -m "$(v memoria)" -w -H -A \
	-o x86.nested_virt=true \
	-s 0,hostbridge \
	-s 1,ahci-hd,"$IMG",bootindex=1 \
	-s 11,hda,play=/dev/dsp,rec="$REC" \
	-s 13,virtio-net,"$(v tap)" \
	-s 29,fbuf,tcp="$(v vnc)",w=1600,h=950 \
	-s 30,xhci,tablet \
	-s 31,lpc \
	-l bootrom,"$UEFI" \
	"$VM"
echo "vm0-13: immagine $IMG, nessun disco dati, rete $(v tap), VNC $(v vnc) (vncviewer localhost:13)"
[ $PROVA = 1 ] && { echo "PROVA, non avvio:"; echo "$@"; exit 0; }
exec "$@"
