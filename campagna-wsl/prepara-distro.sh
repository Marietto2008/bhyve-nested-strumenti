#!/bin/sh
# prepara-distro.sh -- Claude 03/11/2026. Il disco della DISTRO FreeBSD per WSL (wsl --import-in-place FreeBSD ...):
# una copia scrivibile della base 15.2 (fbsd152-wsl.raw, non toccata), separata dalla distro di sistema (la VM, in
# sola lettura). L'init della VM la monta su /distro e vi fa chroot per ogni comando di wsl -d FreeBSD.
# La partizione UFS e' rietichettata fbsddistro: con due dischi collegati, due gpt/rootfs sarebbero ambigui.
# Uso (root): prepara-distro.sh <nome uscita senza estensione>   (es. FreeBSD)
set -eu
NOME=$1
IMG=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini
[ -n "$NOME" ] || exit 4
[ -e "$IMG/distro-$NOME.raw" ] || [ -e "$IMG/distro-$NOME.vhd" ] && { echo "STOP: distro-$NOME esiste gia'"; exit 4; }
cp "$IMG/fbsd152-wsl.raw" "$IMG/distro-$NOME.raw"
md=$(mdconfig -a -t vnode -f "$IMG/distro-$NOME.raw")
trap 'mdconfig -d -u ${md#md} 2>/dev/null' EXIT
gpart show -l $md
gpart modify -i 4 -l fbsddistro $md
gpart show -l $md | grep fbsddistro
mdconfig -d -u ${md#md}; trap - EXIT
qemu-img convert -O vpc -o subformat=fixed,force_size=on "$IMG/distro-$NOME.raw" "$IMG/distro-$NOME.vhd"
sha256 -q "$IMG/distro-$NOME.vhd" > "$IMG/distro-$NOME.vhd.sha256"
ls -la "$IMG/distro-$NOME.vhd"; cat "$IMG/distro-$NOME.vhd.sha256"
