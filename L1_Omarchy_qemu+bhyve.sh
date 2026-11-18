#!/bin/sh
# Avvia Omarchy INSTALLATO sul disco immagine.            [claude 5/10/2026]
#
# Fratello di `installa-omarchy`, che invece avvia la ISO. Qui niente CD,
# niente -kernel: si avvia il disco e il suo bootloader (limine).
#
# ===========================================================================
# no-kvmclock: dov'e' e perche' non e' in /etc/default/grub
# ===========================================================================
# ⚠ Omarchy NON usa GRUB: usa **limine**. Su un Omarchy installato
#   /etc/default/grub NON ESISTE.
# La riga di comando del kernel sta in `limine.conf` sull'ESP (vda1, in
# chiaro anche con il disco cifrato), alla voce `cmdline:`. Li' e' stato
# aggiunto `no-kvmclock`, senza il quale sotto l'acceleratore bhyve il kernel
# muore in pvclock_tsc_khz prima di stampare una riga: schermo nero e nessun
# messaggio da nessuna parte.
# Copia di sicurezza nel guest: /boot/limine.conf.prima-no-kvmclock
#
# ⚠⚠ QUELLA MODIFICA NON E' PERMANENTE. `limine.conf` lo RIGENERA
#    limine-entry-tool a ogni aggiornamento del kernel, e l'aggiunta sparisce.
#    Il modo definitivo, da dare DENTRO Omarchy (serve la radice sbloccata,
#    cioe' la passphrase, quindi lo fa l'utente dopo il primo avvio):
#
#      sudo mkdir -p /etc/limine-entry-tool.d
#      printf 'KERNEL_CMDLINE[default]+=" no-kvmclock"\n' \
#        | sudo tee /etc/limine-entry-tool.d/no-kvmclock.conf
#      sudo limine-mkinitcpio
#
#    E' l'idioma di Omarchy stesso: i suoi aggiustamenti hardware (T2, ASUS)
#    scrivono esattamente file cosi'.
#
# ⚠ All'avvio il disco e' CIFRATO (LUKS su vda2): chiede la passphrase, e la
#   digita l'utente nella finestra VNC. Nessuno script la puo' sapere.
set -u

QEMU=/mnt/linuxulator2/vm/qemu-vmm-build/qemu/build-gpu/qemu-system-x86_64
DISK=/mnt/da0p2/bhyve/img/Linux/linux-ai-omarchy.img
SERIALE=/mnt/zroot-133/omarchy-serial.log
SERIALE_PORTA=4448

[ -e "$QEMU" ] || { echo "manca: $QEMU" >&2; exit 1; }
[ -e "$DISK" ] || { echo "manca: $DISK" >&2; exit 1; }

if pgrep -f "qemu-system-x86_64" >/dev/null 2>&1; then
	echo "C'e' gia' un QEMU in funzione; chiudilo prima." >&2
	exit 1
fi
for v in $(ls /dev/vmm 2>/dev/null); do
	if pgrep -f "bhyve.*$v" >/dev/null 2>&1; then
		echo "La VM bhyve $v e' VIVA: non la tocco." >&2
		exit 1
	fi
	echo "tolgo la voce fantasma /dev/vmm/$v"
	bhyvectl --vm="$v" --destroy >/dev/null 2>&1
done

echo "Schermo: vncviewer 127.0.0.1:5907   Monitor: telnet 127.0.0.1 4447   Seriale: nc 127.0.0.1 $SERIALE_PORTA"
echo "⚠ Il disco e' cifrato: la passphrase va digitata nella finestra VNC."
echo

if [ "${VISUALIZZATORE:-si}" = "si" ]; then
	UTENTE=${UTENTE:-marietto}
	(
		i=0
		while [ $i -lt 60 ]; do
			sockstat -4l 2>/dev/null | grep -q ':5907' && break
			sleep 1
			i=$((i + 1))
		done
		su -m "$UTENTE" -c "env DISPLAY=${SCHERMO_X:-:0} HOME=/home/$UTENTE \
		    /usr/local/bin/vncviewer 127.0.0.1:5907" >/dev/null 2>&1
	) &
	echo "apro il visualizzatore per $UTENTE su ${SCHERMO_X:-:0}"
fi

exec "$QEMU" \
	-accel bhyve \
	-machine q35,hpet=off,i8042=${I8042:-off} \
	-cpu Skylake-Client-v4 \
	-m 8G \
	-smp 8,sockets=1,cores=8,threads=1 \
	-drive file="$DISK",format=raw,if=none,id=disk0,cache=none \
	-device virtio-blk-pci,drive=disk0,bootindex=1 \
	-netdev user,id=net0 \
	-device virtio-net-pci,netdev=net0 \
	-device qemu-xhci,id=usb \
	-device usb-kbd,bus=usb.0 \
	-device usb-tablet,bus=usb.0 \
	-vga std \
	-vnc :7 \
	-chardev socket,id=ser0,host=127.0.0.1,port=$SERIALE_PORTA,server=on,wait=off,logfile="$SERIALE" \
	-serial chardev:ser0 \
	-monitor telnet:127.0.0.1:4447,server,nowait \
	-no-reboot
