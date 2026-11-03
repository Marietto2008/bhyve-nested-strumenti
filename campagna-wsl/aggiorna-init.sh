#!/bin/sh
# aggiorna-init.sh -- Claude 03/11/2026. Sostituisce SOLO l'init WSL (wsl2/fbsd/wslinit/claude-wslinit e il suo rc.d)
# in un'immagine grezza gia' preparata da prepara-immagine-ro.sh, e ne ricava un VHD fixed nuovo: evita di rifare la
# copia dei 6 GB e l'installazione del kernel a ogni modifica dell'init.
# Uso (root): aggiorna-init.sh <immagine grezza esistente, senza .raw> <nome del VHD nuovo, senza .vhd>
set -eu
SORG=$1; NOME=$2
IMG=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini
R=$IMG/radice-fbsd152-wsl
W=/mnt/linuxulator2/vm/wsl2/fbsd/wslinit
[ -n "$SORG" ] && [ -n "$NOME" ] || exit 4
[ -f "$IMG/$SORG.raw" ] || { echo "STOP: manca $IMG/$SORG.raw"; exit 4; }
[ -e "$IMG/$NOME.vhd" ] && { echo "STOP: $IMG/$NOME.vhd esiste gia'"; exit 4; }
mount | grep -q " on $R " && { echo "STOP: $R e' gia' montata"; exit 4; }
md=$(mdconfig -a -t vnode -f "$IMG/$SORG.raw")
trap 'umount "$R" 2>/dev/null; mdconfig -d -u ${md#md} 2>/dev/null' EXIT
mount -t ufs /dev/${md}p4 "$R"
install -m 555 "$W/claude-wslinit" "$R/usr/local/sbin/claude-wslinit"
install -m 555 "$W/claude_wslinit.rc" "$R/usr/local/etc/rc.d/claude_wslinit"
install -d -m 755 "$R/distro"	# (I2) punto di montaggio del disco della distro FreeBSD
# (punto 4) gli strumenti di WSL per la distro (nullfs ro su /usr/lib/wsl): wslexe, l'interop verso Windows
install -d -m 755 "$R/usr/local/libexec/claude-wsl/bin"
install -m 555 "$W/wslexe" "$R/usr/local/libexec/claude-wsl/bin/wslexe"
echo "wslexe: $(sha256 -q "$R/usr/local/libexec/claude-wsl/bin/wslexe")"
# (I2) la debug shell di WSL: porta virtio-serial "hvc2" (LX_INIT_HVC_DEBUG_SHELL) = ttyV0.2; da Windows: wsl --debug-shell
grep -q '^ttyV0.2' "$R/etc/ttys" || printf '%s\n' '# Claude 03/11/2026: debug shell di WSL (porta virtio hvc2, wsl --debug-shell)' \
	'ttyV0.2	"/usr/libexec/getty Pc"	xterm	on  secure' >> "$R/etc/ttys"
grep '^ttyV0.2' "$R/etc/ttys"
# (punto 3) avvio piu' rapido: niente menu beastie, niente attesa dell'autoboot (in WSL nessuno puo' premere un tasto)
sed -i '' -e 's/^autoboot_delay=.*/autoboot_delay="0"/' "$R/boot/loader.conf"
grep -q '^beastie_disable=' "$R/boot/loader.conf" || printf '%s\n' '# Claude 03/11/2026: avvio rapido in WSL' 'beastie_disable="YES"' >> "$R/boot/loader.conf"
grep '^autoboot_delay\|^beastie_disable' "$R/boot/loader.conf"
echo "init aggiornato: $(sha256 -q "$R/usr/local/sbin/claude-wslinit")"
umount "$R"; mdconfig -d -u ${md#md}; trap - EXIT
qemu-img convert -O vpc -o subformat=fixed,force_size=on "$IMG/$SORG.raw" "$IMG/$NOME.vhd"
sha256 -q "$IMG/$NOME.vhd" > "$IMG/$NOME.vhd.sha256"
ls -la "$IMG/$NOME.vhd"; cat "$IMG/$NOME.vhd.sha256"
