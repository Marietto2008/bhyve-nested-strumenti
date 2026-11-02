#!/bin/sh
# vm0-13-qemu.sh -- Claude 02/11/2026. CONFIGURAZIONE A: la stessa VM Windows clone (vm0:13) con QEMU e
# l'acceleratore bhyve con il nested (-accel bhyve,nested=on), invece di bhyve. Stessa immagine, stessi 8 vCPU e
# 32 GB, stesso MAC (00:a0:98:a1:73:65 -> stesso indirizzo DHCP), tap13, VNC 127.0.0.1:5913.
# MAI PROVATA PRIMA del 02/11: il QEMU nested aveva fatto girare solo i KUT.
#   - il disco e' in snapshot=on per DIFETTO: Windows scrive su un file temporaneo (disco interno), l'immagine resta
#     intatta (QEMU = chipset q35: Windows vede hardware nuovo). --scrivi per scrivere davvero sull'immagine.
#   - parte SOLO se non c'e' nessun'altra VM (stessa immagine e stesso nome Windows della vm0:13 sotto bhyve).
# Gira come ROOT. Con --prova stampa il comando e NON avvia niente.
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
PROVA=0; SNAP=on
for a in "$@"; do case $a in --prova) PROVA=1;; --scrivi) SNAP=off;; *) echo "uso: $0 [--prova] [--scrivi]"; exit 4;; esac; done
C=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/macchina-vm13.conf
QEMU=/mnt/linuxulator2/vm/wsl2/fbsd/stage/current/bin/qemu-system-x86_64
QEMU_SHA=650a2bdec6f0fb61ec19066dcd13edd0b647267fd0cec2d0ce8974124b08859a
PCBIOS=/mnt/linuxulator2/vm/wsl2/fbsd/qemu-nested/pc-bios
OVMF_CODE=/usr/local/share/qemu/edk2-x86_64-code.fd
OVMF_VARS=/home/marietto/claude-wsl2-immagini/vm0-13-qemu-vars.fd
export TMPDIR=/home/marietto/claude-wsl2-immagini/tmp	# il file dello snapshot: disco interno, non USB
v() { sed -n "s/^$1=//p" "$C" | head -1; }
[ "$(sha256 -q "$QEMU")" = "$QEMU_SHA" ] || { echo "QEMU diverso da quello approvato"; exit 4; }
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
[ -f "$IMG" ] || { echo "immagine assente: $IMG"; exit 4; }
# 8 vCPU come la vm0:13 sotto bhyve (cpu=sockets=1,cores=8,threads=1 in macchina-vm13.conf)
N=$(v cpu | sed -n 's/.*cores=\([0-9]*\).*/\1/p'); [ -n "$N" ] || N=8
set -- "$QEMU" -name vm0-13-qemu -L "$PCBIOS" \
	-machine q35,hpet=off -accel bhyve,nested=on -cpu max \
	-smp "$N",sockets=1,cores="$N",threads=1 -m "$(v memoria)" \
	-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
	-drive if=pflash,format=raw,file="$OVMF_VARS" \
	-drive file="$IMG",format=raw,if=none,id=d0,cache=none,snapshot=$SNAP \
	-device ide-hd,drive=d0,bus=ide.0,bootindex=1 \
	-netdev tap,id=n0,ifname="$(v tap)",script=no,downscript=no \
	-device virtio-net-pci,netdev=n0,mac=00:a0:98:a1:73:65 \
	-device VGA,xres=1600,yres=950 -display vnc=127.0.0.1:13 \
	-device qemu-xhci -device usb-tablet \
	-monitor none -serial none
echo "vm0-13 (A, QEMU): immagine $IMG snapshot=$SNAP, $N vCPU, rete $(v tap), VNC 127.0.0.1:5913"
[ $PROVA = 1 ] && { echo "PROVA, non avvio:"; echo "$@"; exit 0; }
exec "$@"
