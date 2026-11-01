#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-windowws-qemu-bhyve.sh.non-conforme
echo "INERTE: run-windowws-qemu-bhyve.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-windowws-qemu-bhyve.sh.non-conforme" >&2; exit 4
# Lancia un guest Linux (Windows) via QEMU + accel bhyve, in modo DIAGNOSTICO,
# e APRE DA SOLO una finestra vncviewer con lo schermo del guest (GRUB + boot).
#
#  - VGA std + VNC + vncviewer automatico -> vedi i messaggi a schermo
#  - solo 2 vcpu  -> se il vmm pianta, restano core liberi e l'host sopravvive
#  - console seriale e stderr di qemu su file -> traccia anche se lo schermo si blocca
#
# IMPORTANTE: lancialo COME TE (non con sudo davanti), dal tuo terminale X:
#     sh ~/nested-work/linux-diag/run-linux-bhyve.sh
# chiedera' la password di sudo (serve a qemu per /dev/vmm); la finestra VNC
# esce sul TUO schermo perche' il viewer gira come te.
# Ferma:  sh ~/nested-work/linux-diag/run-windows-bhyve.sh stop

vmdisk1=`geom disk list | awk '/^Geom name: /{d=$NF} /^ *ident: (BE0191500218)/ && d{print d}'`
echo "G-DRIVE USB UFS ; $vmdisk1"

if [ ! -d /mnt/da0p2/bhyve/img/Windows/11 ]; then
echo "gdrive is not imported"
gdrive=no
else
echo "2. gdrive is imported"
gdrive=si
fi

if [ $gdrive = "no" ]; then
echo "gdrive hasn't been imported. Importing..."
doas fsck -y /dev/da0p2
doas mount -t ufs /dev/da0p2 /mnt/da0p2
else
echo "gdrive is already imported"
echo "."
fi

set -u

# ---- parametri (modificabili) ----------------------------------------------
QEMU=/root/qemu-vmm-build/qemu/build/qemu-system-x86_64
PCBIOS=/root/qemu-vmm-build/qemu/pc-bios
#IMG=/mnt/da0p2/bhyve/img/Linux/Debian-warp.img
IMG=/mnt/da0p2/bhyve/img/Windows/11/Windows11.img
UEFI_CODE=/usr/local/share/edk2-qemu/QEMU_UEFI_CODE-x86_64.fd
UEFI_VARS_SRC=/usr/local/share/edk2-qemu/QEMU_UEFI_VARS-x86_64.fd

VCPUS=2
MEM=4096
VNC_DISPLAY=0            # VNC server su 127.0.0.1:5900, viewer su display :0
SSH_FWD=2222

WORK=/mnt/linuxulator2/vm/wsl2/fbsd/
VARS=$WORK/uefi-vars.fd
CONSOLE=$WORK/console.log
QLOG=$WORK/qemu-stderr.log
# ----------------------------------------------------------------------------

mkdir -p "$WORK"

if [ "${1:-}" = "stop" ]; then
	sudo pkill -f "qemu-system-x86_64.*Windows-diag" && echo "fermata" || echo "(gia' ferma)"
	pkill -f "vncviewer 127.0.0.1:$VNC_DISPLAY" 2>/dev/null
	exit 0
fi

for f in "$QEMU" "$IMG" "$UEFI_CODE" "$UEFI_VARS_SRC"; do
	[ -e "$f" ] || { echo "MANCA: $f"; exit 1; }
done
[ -d "$PCBIOS" ] || { echo "MANCA pc-bios: $PCBIOS"; exit 1; }

[ -f "$VARS" ] || cp "$UEFI_VARS_SRC" "$VARS"
: >"$CONSOLE"; : >"$QLOG"

echo "=== Windows via qemu+bhyve: $VCPUS vcpu, ${MEM}MB ==="
echo "    schermo  -> finestra vncviewer (si apre tra poco)"
echo "    seriale  -> $CONSOLE"
echo "    qemu err -> $QLOG"

# qemu ha bisogno di root per /dev/vmm; gira in background
sudo "$QEMU" \
	-accel bhyve \
	-L "$PCBIOS" \
	-machine q35 \
	-cpu max \
	-smp "$VCPUS" \
	-m "$MEM" \
	-drive if=pflash,format=raw,unit=0,readonly=on,file="$UEFI_CODE" \
	-drive if=pflash,format=raw,unit=1,file="$VARS" \
	-drive file="$IMG",format=raw,if=none,id=disk0,cache=none \
	-device virtio-blk-pci,drive=disk0 \
	-netdev user,id=n0,hostfwd=tcp::"$SSH_FWD"-:22 \
	-device virtio-net-pci,netdev=n0 \
	-vga std \
	-vnc 127.0.0.1:"$VNC_DISPLAY" \
	-serial file:"$CONSOLE" \
	-monitor none \
	-name Windows-diag \
	2>"$QLOG" &

# aspetta che il server VNC sia in ascolto, poi apri la finestra COME TE
echo "    attendo il server VNC..."
i=0
while [ $i -lt 30 ]; do
	if sockstat -4l 2>/dev/null | /usr/bin/grep -q "127.0.0.1:$((5900 + VNC_DISPLAY))"; then
		break
	fi
	sleep 0.5; i=$((i + 1))
done

if sockstat -4l 2>/dev/null | /usr/bin/grep -q "127.0.0.1:$((5900 + VNC_DISPLAY))"; then
	echo "    apro vncviewer -> 127.0.0.1:$VNC_DISPLAY"
	vncviewer 127.0.0.1:"$VNC_DISPLAY" &
else
	echo "    !! il server VNC non e' salito: guarda $QLOG (probabile errore accel bhyve)"
	echo "    ultime righe:"; /usr/bin/tail -15 "$QLOG"
fi
