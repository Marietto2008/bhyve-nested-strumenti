#!/bin/sh
# prepara-immagine-wsl.sh -- Claude 02/11/2026. Da un'immagine VM ufficiale di FreeBSD (.vhd.xz) a un VHDX pronto
# per HCS/WSL2: console sulla COM1 (HCS la collega a una named pipe), nome fbsd-wsl, riga di segnale a fine avvio.
# L'originale .vhd.xz NON si tocca. Uso (root): prepara-immagine-wsl.sh <immagine.vhd.xz> <nome base dell'uscita>
# Esempio: prepara-immagine-wsl.sh FreeBSD-15.2-PRERELEASE-amd64-ufs.vhd.xz fbsd152-wsl
#   -> fbsd152-wsl.raw (di lavoro), fbsd152-wsl.vhdx, fbsd152-wsl.vhdx.sha256, nella stessa cartella.
set -eu
[ $# = 2 ] || { echo "uso: $0 <immagine.vhd.xz> <nome base>"; exit 4; }
IN=$(realpath "$1"); D=$(dirname "$IN"); OUT=$D/$2
[ -e "$OUT.raw" ] || [ -e "$OUT.vhdx" ] && { echo "STOP: $OUT.raw o $OUT.vhdx esiste gia'"; exit 4; }
VHD=${IN%.xz}
[ -e "$VHD" ] || xz -dk -T0 "$IN"
qemu-img convert -O raw "$VHD" "$OUT.raw"
M=$D/radice-$2; mkdir -p "$M"
md=$(mdconfig -a -t vnode -f "$OUT.raw")
trap 'umount "$M" 2>/dev/null; mdconfig -d -u "$md" 2>/dev/null' EXIT
# la partizione UFS: la si cerca, non la si presume
p=$(gpart show -p "$md" | awk '$4 == "freebsd-ufs" {print $3; exit}')
[ -n "$p" ] || { echo "nessuna partizione freebsd-ufs in $md"; exit 4; }
mount -t ufs "/dev/$p" "$M"
[ -e "$M/boot/loader.conf" ] && { echo "STOP: l'immagine ha gia' un loader.conf (non previsto)"; exit 4; }
printf '%s\n' '# Claude: FreeBSD come VM di HCS/WSL2. Console sulla COM1 (HCS la collega a una named pipe).' \
	'autoboot_delay="3"' 'boot_multicons="YES"' 'boot_serial="YES"' 'console="comconsole,efi"' 'comconsole_speed="115200"' \
	> "$M/boot/loader.conf"
sed -i '' 's/^hostname="freebsd"$/hostname="fbsd-wsl"/' "$M/etc/rc.conf"
grep -q '^hostname="fbsd-wsl"$' "$M/etc/rc.conf" || { echo "hostname non cambiato"; exit 4; }
[ -e "$M/etc/rc.local" ] && { echo "STOP: l'immagine ha gia' un rc.local (non previsto)"; exit 4; }
printf '%s\n' '#!/bin/sh' '# Claude: segnale inequivocabile di avvio completo, sulla console seriale' \
	'echo "CLAUDE-FBSD-WSL: multiutente raggiunto, $(uname -sr), $(sysctl -n hw.ncpu) CPU, $(sysctl -n kern.vm_guest)" > /dev/console' \
	> "$M/etc/rc.local"
echo "versione nell'immagine: $(cat "$M/bin/freebsd-version" 2>/dev/null | sed -n 's/^USERLAND_VERSION="\(.*\)"/\1/p')"
sync; umount "$M"; mdconfig -d -u "$md"; trap - EXIT
qemu-img convert -O vhdx -o subformat=dynamic "$OUT.raw" "$OUT.vhdx"
qemu-img compare -q -f raw -F vhdx "$OUT.raw" "$OUT.vhdx" || { echo "VHDX diverso dal raw"; exit 4; }
sha256 -q "$OUT.vhdx" > "$OUT.vhdx.sha256"
echo "pronto: $OUT.vhdx sha256 $(cut -c1-16 "$OUT.vhdx.sha256")..."
