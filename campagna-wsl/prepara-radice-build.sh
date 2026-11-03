#!/bin/sh
# prepara-radice-build.sh -- Claude 03/11/2026. Ambiente di compilazione FreeBSD 15.2 per i pezzi di WSLg (FreeRDP-mirror,
# weston-mirror, WSLGd): i binari vanno nella VM/distro 15.2, l'host e' 16-CURRENT. Copia la base dall'immagine di
# partenza fbsd152-wsl.raw (montata IN SOLA LETTURA, non toccata) in build/radice152; poi pkg FreeBSD:15 dentro il
# chroot (vedi entra-radice-build.sh).
# Uso (root): prepara-radice-build.sh
set -eu
IMG=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/fbsd152-wsl.raw
B=/mnt/linuxulator2/vm/wsl2-freebsd-work/build
DST=$B/radice152
M=$B/mnt-fbsd152-ro
[ -e "$DST" ] && { echo "STOP: $DST esiste gia'"; exit 4; }
mkdir -p "$M"
mount | grep -q " on $M " && { echo "STOP: $M e' gia' montata"; exit 4; }
md=$(mdconfig -a -t vnode -o readonly -f "$IMG")
trap 'umount "$M" 2>/dev/null; mdconfig -d -u ${md#md} 2>/dev/null' EXIT
mount -t ufs -o ro /dev/${md}p4 "$M"
mkdir -p "$DST"
( cd "$M" && tar -cf - --exclude ./usr/local --exclude ./var/db/pkg . ) | ( cd "$DST" && tar -xpf - )
umount "$M"; mdconfig -d -u ${md#md}; trap - EXIT
cp /etc/resolv.conf "$DST/etc/resolv.conf"
"$DST/usr/bin/uname" -a 2>/dev/null || true
grep USERLAND_VERSION= "$DST/bin/freebsd-version"
du -sh "$DST"
