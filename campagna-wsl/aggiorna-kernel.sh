#!/bin/sh
# aggiorna-kernel.sh -- Claude 04/11/2026. Installa il kernel <KERNCONF> appena compilato (ramo wsf/guest-wsl2-fix) in
# un'immagine grezza GIA' preparata da prepara-immagine-ro.sh, poi ne ricava il VHD con aggiorna-init.sh (init,
# strumenti, ttys, loader.conf, rc.conf): evita di ricopiare i 6 GB della base a ogni prova del kernel.
# Uso (root): aggiorna-kernel.sh <KERNCONF> <immagine grezza esistente, senza .raw> <nome del VHD nuovo, senza .vhd>
set -eu
KC=$1; SORG=$2; NOME=$3
SRC=/mnt/linuxulator2/vm/wsl2-freebsd-work/src/freebsd-guest
OBJ=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/obj-guest
IMG=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini
R=$IMG/radice-fbsd152-wsl
[ -n "$KC" ] && [ -n "$SORG" ] && [ -n "$NOME" ] || exit 4
[ -f "$IMG/$SORG.raw" ] || { echo "STOP: manca $IMG/$SORG.raw"; exit 4; }
mount | grep -q " on $R " && { echo "STOP: $R e' gia' montata"; exit 4; }
md=$(mdconfig -a -t vnode -f "$IMG/$SORG.raw")
trap 'umount "$R" 2>/dev/null; mdconfig -d -u ${md#md} 2>/dev/null' EXIT
mount -t ufs /dev/${md}p4 "$R"
( cd "$SRC" && env MAKEOBJDIRPREFIX=$OBJ make installkernel KERNCONF=$KC DESTDIR="$R" >/dev/null )
strings "$R/boot/kernel/kernel" | grep -m1 'wsf/'
umount "$R"; mdconfig -d -u ${md#md}; trap - EXIT
sh "$(dirname "$0")/aggiorna-init.sh" "$SORG" "$NOME"
