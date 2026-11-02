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
SIPI=0; NICOPT=""; TRACCIA=1; AUDIO=0
for a in "$@"; do case $a in --prova) PROVA=1;; --scrivi) SNAP=off;; --snapshot) SNAP=on;; --qemu-sipi) SIPI=1;;
	--nic-noeventidx) NICOPT=",event_idx=off";;
	--trace-virtio) TRACCIA=1;;	# 02/11: eventi virtio/MSI-X dall'avvio in un file a parte (rete intermittente)
	--audio) AUDIO=1;;		# 02/11: HDA di q35 (driver incluso in Windows) su /dev/dsp, come hda in B	# 02/11: prova diagnostica della ricezione virtio-net bloccata
	*) echo "uso: $0 [--prova] [--snapshot] [--qemu-sipi] [--nic-noeventidx] [--trace-virtio] [--audio]"; exit 4;; esac; done
C=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/macchina-vm13.conf
QEMU=/mnt/linuxulator2/vm/wsl2/fbsd/stage/current/bin/qemu-system-x86_64
QEMU_SHA=650a2bdec6f0fb61ec19066dcd13edd0b647267fd0cec2d0ce8974124b08859a
# --qemu-sipi (Claude 02/11): lo stesso QEMU + wait-for-SIPI (qemu-sipi 883658d899): con OVMF a piu' vCPU gli AP
# eseguivano il firmware dal vettore di reset fra INIT e SIPI (triple fault con nested, blocco con 32 GB)
if [ $SIPI = 1 ]; then
	QEMU=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/qemu-sipi/qemu-system-x86_64
	QEMU_SHA=a572a673e9acebd4e9f0a592d114116570cb16d6a5342ecdd760b1131edab53f
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
	-device virtio-net-pci,netdev=n0,mac=00:a0:98:a1:73:65$NICOPT \
	-device VGA,xres=1600,yres=950 -display vnc=127.0.0.1:13 \
	-device qemu-xhci -device usb-tablet \
	-monitor none -serial none
echo "vm0-13 (A, QEMU): immagine $IMG snapshot=$SNAP, $N vCPU, rete $(v tap), VNC 127.0.0.1:5913"
if [ $TRACCIA = 1 ]; then
	TF=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs/vm0-13-qemu-trace-$(date +%Y%m%d-%H%M%S).txt
	set -- "$@" -D "$TF" -trace enable=virtio_set_status -trace enable=virtio_queue_notify -trace enable=virtio_notify \
		-trace enable=msix_write_config -trace enable=virtio_pci_notify_write
	echo "traccia virtio: $TF"
fi
if [ $AUDIO = 1 ]; then
	DSP=$(awk -F: '/^pcm[0-9]+:/ && /play/ {sub("pcm","",$1); print "/dev/dsp" $1; exit}' /dev/sndstat); [ -n "$DSP" ] || DSP=/dev/dsp
	set -- "$@" -audiodev oss,id=snd0,out.dev="$DSP",in.dev="$DSP" -device ich9-intel-hda -device hda-duplex,audiodev=snd0
	echo "audio: $DSP"
fi
[ $PROVA = 1 ] && { echo "PROVA, non avvio:"; echo "$@"; exit 0; }
# 02/11: Windows+Hyper-V va lanciato con la EPT ombra in modalita' keep (collaudata, #81): si fissa alla CREAZIONE
# dei vCPU. Con vept_keep=0 ogni ingresso in L2 butta via le foglie: 250.000 INVEPT e fault EPT02 al secondo, Windows
# ferma e QEMU al 300%; con 1: SSH dopo 64 s, QEMU 70-130%.
sysctl hw.vmm.vmx.vept_keep=1 >/dev/null || { echo "vept_keep=1 non impostabile"; exit 4; }
exec "$@"
