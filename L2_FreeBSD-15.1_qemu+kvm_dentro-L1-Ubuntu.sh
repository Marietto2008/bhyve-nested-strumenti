#!/bin/bash
# avvia-freebsd151.sh -- Claude 07/11/2026. NELL'L1 Ubuntu, come marietto. Avvia l'L2 FreeBSD 15.1 con QEMU+KVM:
# e' la VM annidata (host FreeBSD + bhyve nested -> Ubuntu L1 -> KVM -> FreeBSD L2).
#
#   ./avvia-freebsd151.sh            finestra nel desktop KDE (o VNC 127.0.0.1:5901 se non c'e' un desktop)
#   CPU=2 MEM=2G ./avvia-freebsd151.sh
#
# Rete: QEMU utente (NAT): SSH dall'L1 con  ssh -p 2222 marietto@127.0.0.1
# Seriale: socket $D/seriale.sock (es.  socat - UNIX-CONNECT:seriale.sock), copia in seriale.log
# Monitor QEMU: $D/monitor.sock (system_powerdown = tasto ACPI)
# Mouse: tablet USB (posizione assoluta): il puntatore entra ed esce senza cattura e senza rimbalzi ai bordi.
# Il controller USB sta nello slot 5: senza addr= prendeva lo slot 3 del disco, e la voce di avvio UEFI salvata
# (Pci 0x3) non trovava piu' il disco -> la VM non partiva.
set -euo pipefail
D=$(cd "$(dirname "$0")" && pwd)
: "${CPU:=4}" "${MEM:=4G}"
CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
for f in "$D/freebsd151.qcow2" "$D/freebsd151-VARS.fd" "$D/seed.iso" "$CODE"; do [ -e "$f" ] || { echo "manca $f (prima prepara-freebsd151.sh)"; exit 4; }; done
[ -c /dev/kvm ] || { echo "manca /dev/kvm: l'L1 non vede VMX (nidificazione dell'host?) o kvm_intel non caricato"; exit 4; }
[ -r /dev/kvm ] && [ -w /dev/kvm ] || { echo "/dev/kvm non accessibile: marietto deve stare nel gruppo kvm"; exit 4; }
pgrep -f "qemu-system-x86_64 -name freebsd151-l2" >/dev/null && { echo "freebsd151-l2 gira gia'"; exit 4; }

if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then SCHERMO=(-display gtk); else SCHERMO=(-display none -vnc 127.0.0.1:1); fi
exec qemu-system-x86_64 -name freebsd151-l2 \
	-machine q35,accel=kvm -cpu host -smp "$CPU" -m "$MEM" \
	-drive if=pflash,format=raw,readonly=on,file="$CODE" \
	-drive if=pflash,format=raw,file="$D/freebsd151-VARS.fd" \
	-drive if=virtio,format=qcow2,file="$D/freebsd151.qcow2" \
	-drive file="$D/seed.iso",format=raw,media=cdrom,readonly=on \
	-nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
	-device qemu-xhci,addr=0x5 -device usb-tablet \
	-chardev socket,id=s0,path="$D/seriale.sock",server=on,wait=off,logfile="$D/seriale.log" -serial chardev:s0 \
	-monitor unix:"$D/monitor.sock",server,nowait \
	"${SCHERMO[@]}"
