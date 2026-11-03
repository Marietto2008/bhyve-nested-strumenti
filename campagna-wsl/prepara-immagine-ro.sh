#!/bin/sh
# prepara-immagine-ro.sh -- Claude 03/11/2026. Immagine FreeBSD 15.2 per la VM di WSL2 come «distro di sistema»:
# WSL la collega via SCSI IN SOLA LETTURA alla creazione della VM (ADR-002), quindi la radice deve restare ro.
# Parte da fbsd152-wsl.raw (preparata il 02/11, non toccata) e produce <nome>.raw e <nome>.vhd (VHD fixed:
# il servizio vuole l'estensione .vhd per collegarla via SCSI):
#  - kernel <KERNCONF> del ramo wsf/guest-wsl2-fix (correzioni vPCI/MSI) come kernel predefinito; l'ufficiale resta
#    in kernel.old (installkernel lo sposta da se');
#  - fstab: / in sola lettura, niente swap ne' ESP (scriverebbero sul disco);
#  - rc.conf: root_rw_mount=NO, /var e /tmp in memoria;
#  - loader.conf: virtio_console caricato all'avvio (in GENERIC e' un modulo).
# Uso (root): prepara-immagine-ro.sh <KERNCONF> <nome uscita>   (es. CLAUDE-WSL fbsd152-wsl-ro1)
set -eu
KC=$1; NOME=$2
SRC=/mnt/linuxulator2/vm/wsl2-freebsd-work/src/freebsd-guest
OBJ=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/obj-guest
IMG=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini
R=$IMG/radice-fbsd152-wsl
[ -n "$NOME" ] || exit 4
[ -e "$IMG/$NOME.raw" ] || [ -e "$IMG/$NOME.vhd" ] && { echo "STOP: $IMG/$NOME.raw o .vhd esiste gia'"; exit 4; }
mount | grep -q " on $R " && { echo "STOP: $R e' gia' montata"; exit 4; }
( cd "$SRC" && [ "$(git branch --show-current)" = wsf/guest-wsl2-fix ] ) || { echo "STOP: il sorgente non e' su wsf/guest-wsl2-fix"; exit 4; }

echo "1. copia dell'immagine di partenza"
cp "$IMG/fbsd152-wsl.raw" "$IMG/$NOME.raw"
md=$(mdconfig -a -t vnode -f "$IMG/$NOME.raw")
trap 'umount "$R" 2>/dev/null; mdconfig -d -u ${md#md} 2>/dev/null' EXIT
mount -t ufs /dev/${md}p4 "$R"

echo "2. kernel $KC"
( cd "$SRC" && env MAKEOBJDIRPREFIX=$OBJ make installkernel KERNCONF=$KC DESTDIR="$R" >/dev/null )
strings "$R/boot/kernel/kernel" | grep -m1 'wsf/guest'

echo "3. fstab, rc.conf, loader.conf"
cp "$R/etc/fstab" "$R/etc/fstab.claude-prima-ro"
cat > "$R/etc/fstab" <<'FSTABFINE'
# Claude 03/11/2026: radice in SOLA LETTURA (WSL collega la distro di sistema ro). Originale in fstab.claude-prima-ro
/dev/gpt/rootfs	/	ufs	ro,noatime	0	0
FSTABFINE
cat >> "$R/etc/rc.conf" <<'RCFINE'
# Claude 03/11/2026: radice in sola lettura, /var e /tmp in memoria (WSL collega la distro di sistema ro)
root_rw_mount="NO"
varmfs="YES"
varsize="64m"
populate_var="YES"
tmpmfs="YES"
tmpsize="64m"
dumpdev="NO"
RCFINE
printf '%s\n' '# Claude 03/11/2026: la console virtio di WSL (in GENERIC e'"'"' un modulo)' 'virtio_console_load="YES"' \
	>> "$R/boot/loader.conf"
tail -3 "$R/boot/loader.conf"; grep -v '^#' "$R/etc/fstab"

# 3b. (03/11) l'init minimale che parla col servizio WSL, se compilato (wsl2/fbsd/wslinit)
W=/mnt/linuxulator2/vm/wsl2/fbsd/wslinit
if [ -x "$W/claude-wslinit" ]; then
	install -d -m 755 "$R/usr/local/sbin"
	install -m 555 "$W/claude-wslinit" "$R/usr/local/sbin/claude-wslinit"
	install -d -m 755 "$R/usr/local/etc/rc.d"
	install -m 555 "$W/claude_wslinit.rc" "$R/usr/local/etc/rc.d/claude_wslinit"
	printf '%s\n' 'claude_wslinit_enable="YES"' >> "$R/etc/rc.conf"
	echo "init WSL installato: $(sha256 -q "$R/usr/local/sbin/claude-wslinit")"
fi

echo "4. smonto e converto in VHD fixed"
umount "$R"; mdconfig -d -u ${md#md}; trap - EXIT
qemu-img convert -O vpc -o subformat=fixed,force_size=on "$IMG/$NOME.raw" "$IMG/$NOME.vhd"
sha256 -q "$IMG/$NOME.vhd" > "$IMG/$NOME.vhd.sha256"
ls -la "$IMG/$NOME.vhd"; cat "$IMG/$NOME.vhd.sha256"
