#!/bin/bash
# prepara-freebsd151.sh -- Claude 07/11/2026. NELL'L1 Ubuntu, come marietto (niente root).
# Prepara il disco dell'L2 FreeBSD 15.1: immagine UFFICIALE FreeBSD-15.1-RELEASE amd64 BASIC-CLOUDINIT (UFS), SHA256
# verificato col CHECKSUM.SHA256 del sito, allargata a 50 GB (qcow2: occupa solo quanto scritto; growfs allarga
# la radice da solo al primo avvio). Al primo avvio nuageinit legge seed.iso (etichetta cidata) e crea l'utente
# marietto (gruppo wheel, sudo), la sua chiave SSH e il nome freebsd151-l2.
#
#   ./prepara-freebsd151.sh HASH-PASSWORD      HASH = riga di  openssl passwd -6  (la password in chiaro non serve)
#
# Non sovrascrive nulla: se il disco esiste gia' si ferma.
set -euo pipefail
D=$(cd "$(dirname "$0")" && pwd)
REL=15.1-RELEASE
URL=https://download.freebsd.org/releases/VM-IMAGES/$REL/amd64/Latest
XZ=FreeBSD-$REL-amd64-BASIC-CLOUDINIT-ufs.qcow2.xz
DISCO=$D/freebsd151.qcow2
DIM=50G
HASH=${1:-}

[[ $HASH == '$6$'* ]] || { echo "uso: $0 'HASH openssl passwd -6'"; exit 4; }
[ ! -e "$DISCO" ] || { echo "esiste gia' $DISCO: non lo tocco"; exit 4; }
for c in curl xz qemu-img cloud-localds sha256sum ssh-keygen; do command -v $c >/dev/null || { echo "manca $c"; exit 4; }; done
LIBERI=$(df --output=avail -B1G "$D" | tail -1 | tr -d ' ')
echo "spazio libero in $D: ${LIBERI} GB (il disco puo' arrivare a ${DIM})"
[ "$LIBERI" -ge 55 ] || { echo "servono almeno 55 GB liberi (50 del disco + margine)"; exit 4; }

cd "$D"
curl -fsS "$URL/CHECKSUM.SHA256" -o CHECKSUM.SHA256-$REL
ATTESO=$(sed -n "s/^SHA256 ($XZ) = //p" CHECKSUM.SHA256-$REL)
[ ${#ATTESO} = 64 ] || { echo "sha atteso non trovato in CHECKSUM.SHA256-$REL"; exit 4; }
[ -f "$XZ" ] && echo "$ATTESO  $XZ" | sha256sum -c --quiet - 2>/dev/null || curl -fL --retry 3 -o "$XZ" "$URL/$XZ"
echo "$ATTESO  $XZ" | sha256sum -c - || { echo "SHA256 SBAGLIATO: non uso $XZ"; exit 4; }

xz -dkc "$XZ" > "$DISCO.parziale"
qemu-img resize -f qcow2 "$DISCO.parziale" $DIM
mv "$DISCO.parziale" "$DISCO"
qemu-img info "$DISCO" | grep -E 'virtual size|disk size'

cp /usr/share/OVMF/OVMF_VARS_4M.fd "$D/freebsd151-VARS.fd"

# chiave dell'utente dell'L1 (la crea se manca)
[ -f ~/.ssh/id_ed25519.pub ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519
CHIAVE=$(cat ~/.ssh/id_ed25519.pub)

cat > "$D/meta-data" <<FINE_META
instance-id: freebsd151-l2-001
local-hostname: freebsd151-l2
FINE_META
cat > "$D/user-data" <<FINE_UD
#cloud-config
hostname: freebsd151-l2
users:
  - name: marietto
    gecos: marietto
    groups: wheel
    shell: /bin/sh
    passwd: '$HASH'
    ssh_authorized_keys:
      - $CHIAVE
ssh_pwauth: true
packages:
  - sudo
write_files:
  - path: /usr/local/etc/sudoers.d/wheel
    permissions: '0440'
    content: |
      %wheel ALL=(ALL:ALL) ALL
FINE_UD
cloud-localds "$D/seed.iso" "$D/user-data" "$D/meta-data"
echo "PRONTO: $DISCO + seed.iso. Avvio: $D/avvia-freebsd151.sh"
