#!/bin/sh
# prepara-disco-avvio.sh -- Claude 03/11/2026. Disco di AVVIO piccolo per le prove di kernel FreeBSD nella VM di HCS/WSL:
# /boot dell'immagine 15.2 (loader, lua, defaults, device.hints) + kernel di prova in /boot/kernel.claude + loader.conf
# che monta la radice dal disco PRINCIPALE (vfs.root.mountfrom=ufs:/dev/gpt/rootfs). Il disco principale non si tocca.
# Uso (root: mdconfig, mount, installkernel): prepara-disco-avvio.sh <KERNCONF> <nome uscita> [righe in piu' per
# loader.conf, separate da ';', es. 'virtio_console_load="YES"']   (es. CLAUDE-WSL avvio-dbg1)
set -eu
KC=$1; NOME=$2; PIU=${3:-}
SRC=/mnt/linuxulator2/vm/wsl2-freebsd-work/src/freebsd-guest
OBJ=/mnt/linuxulator2/vm/wsl2-freebsd-work/build/obj-guest
IMG=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini
ST=$IMG/stage-$NOME
[ -e "$ST" ] || [ -e "$IMG/$NOME.vhdx" ] && { echo "STOP: $ST o $IMG/$NOME.vhdx esiste gia'"; exit 4; }
mkdir -p "$ST/boot"
# 1. kernel di prova
( cd "$SRC" && env MAKEOBJDIRPREFIX=$OBJ make installkernel KERNCONF=$KC DESTDIR="$ST" KODIR=/boot/kernel.claude >/dev/null )
# i simboli di debug (usr/lib/debug, ~300 MB) restano sull'host per kgdb, fuori dal disco di avvio
[ -n "$NOME" ] && [ -d "$ST/usr" ] && mv "$ST/usr" "$IMG/simboli-debug-$NOME"
# 2. /boot dell'immagine (sola lettura), senza il kernel ufficiale
md=$(mdconfig -a -t vnode -o readonly -f "$IMG/fbsd152-wsl.raw")
mount -t ufs -o ro /dev/${md}p4 "$IMG/radice-fbsd152-wsl"
( cd "$IMG/radice-fbsd152-wsl/boot" && tar -cf - --exclude ./kernel --exclude ./kernel.old . ) | ( cd "$ST/boot" && tar -xf - )
umount "$IMG/radice-fbsd152-wsl"; mdconfig -d -u ${md#md}
# 3. loader.conf: console seriale, kernel di prova, radice sul disco principale
cat > "$ST/boot/loader.conf" <<'CONFFINE'
# Claude: disco di AVVIO per prove; la radice resta sul disco principale
autoboot_delay="3"
boot_multicons="YES"
boot_serial="YES"
console="comconsole,efi"
comconsole_speed="115200"
kernel="kernel.claude"
vfs.root.mountfrom="ufs:/dev/gpt/rootfs"
debug.kdb.alt_break_to_debugger="1"
CONFFINE
[ -n "$PIU" ] && printf '%s\n' "$PIU" | tr ';' '\n' >> "$ST/boot/loader.conf"
# 4. file system e GPT
makefs -t ffs -B little -o version=2 -s 256m "$IMG/$NOME.ufs" "$ST"
mkimg -s gpt -p freebsd-ufs/claudeboot:="$IMG/$NOME.ufs" -o "$IMG/$NOME.raw"
qemu-img convert -O vhdx -o subformat=dynamic "$IMG/$NOME.raw" "$IMG/$NOME.vhdx"
sha256 -q "$IMG/$NOME.vhdx" > "$IMG/$NOME.vhdx.sha256"
ls -la "$IMG/$NOME.vhdx"; cat "$IMG/$NOME.vhdx.sha256"
