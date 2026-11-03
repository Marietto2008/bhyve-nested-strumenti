#!/bin/sh
# entra-radice-build.sh -- Claude 03/11/2026. Esegue un comando nel chroot 15.2 di compilazione (build/radice152), con
# devfs montato per la durata del comando. L'ABI per pkg e' quella della radice: FreeBSD:15:amd64.
# Uso (root): entra-radice-build.sh <comando sh>
set -eu
DST=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/radice152
[ -x "$DST/bin/sh" ] || { echo "STOP: manca $DST"; exit 4; }
mount | grep -q " on $DST/dev " || mount -t devfs devfs "$DST/dev"
trap 'umount "$DST/dev" 2>/dev/null' EXIT
env -i PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin HOME=/root TERM=dumb \
	ABI=FreeBSD:15:amd64 IGNORE_OSVERSION=yes ASSUME_ALWAYS_YES=yes \
	chroot "$DST" /bin/sh -c "$1"
