#!/bin/sh
# sonda-h1-sudo.sh -- Claude 31/10/2026, parere Opus sulla separazione par. 1.2. SONDA DELL'HOST, NON nel giro ordinario:
# riproduce il difetto H1 (SIGINT a sudo NON ferma il figlio) col sudo VERO. Il difetto dipende da sudo e da /bin/sh:
# rieseguirla solo quando cambiano (aggiornamento di pkg o di world). Gira come marietto; solo processi sleep.
# Registra versione e sha di sudo e /bin/sh. Uso: sonda-h1-sudo.sh <cartella nuova in logs/>
set -u
B=/mnt/linuxulator2/vm/wsl2/linux
. $B/caldo/guardia.sh
O=${1:?cartella}
case "$O" in $B/logs/*) ;; *) echo "uscita fuori da $B/logs"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste gia'"; exit 2; }
mkdir -p "$O" || exit 2
[ "$(/usr/bin/id -un)" != collaudo ] || { echo "STOP: la sonda usa il genitore privilegiato vero: non come collaudo"; exit 2; }
. $B/opnd-manifest.sh
echo "sudo: $(/usr/local/bin/sudo -V | /usr/bin/head -1); sha $(/sbin/sha256 -q /usr/local/bin/sudo); pacchetto $(/usr/sbin/pkg which -q /usr/local/bin/sudo 2>/dev/null)"
echo "/bin/sh: sha $(/sbin/sha256 -q /bin/sh); $(/bin/freebsd-version -ku | /usr/bin/tr '\n' ' ')"
nf=0; nok=0
ok() { nok=$((nok+1)); echo "  ok      $*"; }
no() { nf=$((nf+1)); echo "  ERRATO  $*"; }
caso() { N=$1; OM_OUT=$O/$1; mkdir -p "$OM_OUT"; : > "$OM_OUT/manifest.txt"; }
echo "0. il difetto: SIGINT al genitore privilegiato NON ferma il figlio (riproduzione)"
caso c0
guardia_azione || exit 4; sudo -n /bin/sleep 30 & S=$!; sleep 1
guardia_azione && sudo -n /bin/kill -INT $S; sleep 1
F=$(o_figlio $S sleep)
[ -n "$F" ] && ok "c0: dopo SIGINT al genitore privilegiato il figlio sleep $F e' ancora vivo (difetto H1 riprodotto)" || no "c0: il figlio e' morto: H1 NON riprodotto"
om_ferma_dtrace $S 5 sleep >/dev/null 2>&1

echo "SUMMARY: $nok ok, $nf errati"
[ $nf = 0 ]
