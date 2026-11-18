#!/bin/sh
# Installa Omarchy 4.0.4 dentro linux-ai-omarchy.img.      [claude 5/10/2026]
#
# ===========================================================================
# PERCHE' UNO SCRIPT SEPARATO, E NON start-gpu-passthru-linux-omarchy-ai
# ===========================================================================
# Sono due problemi diversi e conviene non legarli:
#   installare il sistema nell'immagine   <- questo script, il minimo che serve
#   farlo girare con UEFI e la RTX        <- l'altro script, dopo
#
# Nell'altro script l'avvio di Omarchy non riusciva per TRE motivi distinti,
# tutti misurati, nessuno indovinato:
#
#  1. ⚠ Avviava ancora kernel e initramfs di LINUX-AI STAR con il CD di
#     Omarchy dentro. Quell'initramfs cerca /Linux-AI-Star/, non lo trova e
#     lascia il guest nella PROPRIA shell di emergenza ("/ #" con bin dev etc
#     init lib memory mnt proc root run sbin shutdown sys tmp usr var).
#     Sembra un guasto della VM: non lo e'.
#
#  2. ⚠ Con -kernel/-initrd sotto OVMF il firmware si PIANTA prima di avviare
#     il kernel. Firma dal monitor QEMU: CPU al 106% e, su DIECI campioni di
#     `info registers`, EIP=7e91b420 ed ESI=7fdf5960 SEMPRE IDENTICI. Se
#     stesse copiando l'initramfs, ESI avanzerebbe. Un anello di una
#     istruzione e' CpuDeadLoop(): OVMF morto su un errore fatale, con 253 MB
#     di initramfs da travasare per fw_cfg.
#     ★ Qui si usa SeaBIOS (niente -drive if=pflash), dove il caricamento
#       diretto del kernel e' la strada piu' battuta di QEMU.
#
#  3. ⚠⚠ Lasciando avviare la ISO da sola, il suo GRUB NON HA MENU:
#          timeout=0
#          timeout_style=hidden
#     Avvia la voce predefinita all'istante. Non c'e' niente da interrompere
#     con 'e', e la voce predefinita NON contiene no-kvmclock.
#     ★ Ci ho sbattuto contro tre volte prima di leggere il grub.cfg: prima
#       aspettando "tre secondi a occhio", poi con una sonda che confrontava
#       due fotografie -- INVALIDA, perche' il menu ha un conto alla rovescia
#       che cambia lo schermo DA SOLO -- poi mandando 84 tasti in 10 secondi.
#       La risposta era nel file, non nei tentativi.
#
# ===========================================================================
# no-kvmclock NON E' OPZIONALE
# ===========================================================================
# Con l'acceleratore bhyve il guest riceve la firma di paravirtualizzazione
# KVM con i parametri di taratura a ZERO: Linux inizializza kvm-clock, divide
# per zero e muore in pvclock_tsc_khz PRIMA di stampare una riga. Sintomo:
# schermo nero e nessun messaggio da nessuna parte.
# ⚠ `-cpu ...,kvm=off` NON basta: la firma viene dall'acceleratore.
# ⚠ A sistema INSTALLATO: mettere no-kvmclock in /etc/default/grub DENTRO il
#   guest e rigenerare la configurazione, PRIMA di spegnere, o il disco non
#   riavviera' mai.
#
# ===========================================================================
set -u

QEMU=/mnt/linuxulator2/vm/qemu-vmm-build/qemu/build-gpu/qemu-system-x86_64
ISO=/mnt/linuxulator2/vm/ISO/Linux/omarchy-4.0.4.iso
DISK=/mnt/da0p2/bhyve/img/Linux/linux-ai-omarchy.img
BOOT=/mnt/linuxulator2/vm/qemu-vmm-build/omarchy-boot/arch/boot/x86_64
SERIALE=/mnt/zroot-133/omarchy-install-serial.log
# ⚠ La console seriale e' una SOCKET (127.0.0.1:4448), non piu' solo un file.
#   Con `-serial file:` si poteva solo LEGGERE: utile per la diagnosi, inutile
#   per intervenire. Il sistema installato non si avvia finche' non gli si
#   aggiunge no-kvmclock, quindi la modifica va fatta dall'ambiente live --
#   e per farla serve poterci SCRIVERE, cioe' fare il login sulla console.
#   `-chardev socket,...,logfile=` da' tutte e due le cose: la socket per
#   lavorarci e il file di log di sempre, che resta leggibile con tail -f.
#   Ci si collega con:   nc 127.0.0.1 4448        (oppure da uno script)
SERIALE_PORTA=4448

# I parametri archiso sono quelli del grub.cfg DENTRO la ISO, piu' i nostri.
#   archisobasedir=arch        dove guardare nel supporto
#   archisolabel=OMARCHY_202609 come riconoscerlo: etichetta del volume, letta
#                              dal descrittore primario della ISO
#   no-kvmclock                vedi sopra
#   console=ttyS0,115200       cosi' si vede DOVE si ferma, se si ferma
# Niente `quiet splash`: in diagnosi il silenzio e' il nemico.
RIGA=${RIGA:-"archisobasedir=arch archisolabel=OMARCHY_202609 no-kvmclock console=tty0 console=ttyS0,115200"}

for f in "$QEMU" "$ISO" "$DISK" "$BOOT/vmlinuz-linux-t2" "$BOOT/initramfs-linux-t2.img"; do
	[ -e "$f" ] || { echo "manca: $f" >&2; exit 1; }
done

# ⚠ Una VM QEMU per volta con questo acceleratore, e nessuna voce fantasma in
#   /dev/vmm: una voce senza processo bhyve e' il residuo di una VM uccisa, e
#   impedisce di avviarne un'altra.
if pgrep -f "qemu-system-x86_64" >/dev/null 2>&1; then
	echo "C'e' gia' un QEMU in funzione; chiudilo prima." >&2
	pgrep -lf qemu-system-x86_64 | cut -c1-90 >&2
	exit 1
fi
for v in $(ls /dev/vmm 2>/dev/null); do
	if pgrep -f "bhyve.*$v" >/dev/null 2>&1; then
		echo "La VM bhyve $v e' VIVA: non la tocco. Chiudila tu." >&2
		exit 1
	fi
	echo "tolgo la voce fantasma /dev/vmm/$v"
	bhyvectl --vm="$v" --destroy >/dev/null 2>&1
done

: >| "$SERIALE" 2>/dev/null || true
echo "Seriale del guest: $SERIALE   (tail -f per seguirla)"
echo "Schermo: vncviewer 127.0.0.1:5907   Monitor: telnet 127.0.0.1 4447   Seriale: nc 127.0.0.1 $SERIALE_PORTA"
echo

# ⚠ APRIRE DA SOLI IL VISUALIZZATORE.   [claude 5/10/2026]
#   La prima versione si limitava a STAMPARE il comando, e la VM e' rimasta
#   per minuti alla schermata "Press Return to Start Install" senza che
#   nessuno la vedesse: dall'esterno sembrava che non succedesse niente, e
#   invece era gia' pronta. Un avvio che nessuno guarda e' un avvio che per
#   l'utente non e' avvenuto.
#   ⚠ Lo script gira da root (serve per bhyve), ma la finestra va aperta
#     nella sessione X dell'utente, non in quella di root.
#   Per non aprirlo:  VISUALIZZATORE=no ./installa-omarchy
if [ "${VISUALIZZATORE:-si}" = "si" ]; then
	UTENTE=${UTENTE:-marietto}
	(
		# si aspetta che QEMU ascolti davvero, invece di sperarci
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
	-machine q35,hpet=off \
	-cpu Skylake-Client-v4 \
	-m 8G \
	-smp 8,sockets=1,cores=8,threads=1 \
	-drive file="$DISK",format=raw,if=none,id=disk0,cache=none \
	-device virtio-blk-pci,drive=disk0 \
	-drive file="$ISO",media=cdrom,if=none,id=cd0,readonly=on \
	-device ide-cd,drive=cd0 \
	-kernel "$BOOT/vmlinuz-linux-t2" \
	-initrd "$BOOT/initramfs-linux-t2.img" \
	-append "$RIGA" \
	-netdev user,id=net0 \
	-device virtio-net-pci,netdev=net0 \
	-vga std \
	-vnc :7 \
	-chardev socket,id=ser0,host=127.0.0.1,port=4448,server=on,wait=off,logfile="$SERIALE" \
	-serial chardev:ser0 \
	-monitor telnet:127.0.0.1:4447,server,nowait \
	-no-reboot
