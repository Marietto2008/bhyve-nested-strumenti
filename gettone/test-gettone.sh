#!/bin/sh
# test-gettone.sh -- Claude 31/10/2026. Collaudo di gettone_valido (gettone-lib.sh), come utente collaudo: i gettoni
# sono file di collaudo (uid atteso = quello di collaudo, in produzione 0). Uso: sudo -u collaudo sh test-gettone.sh <cartella>
set -u
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh
VL_DIR=/mnt/linuxulator2/vm/nested-work/installazione/files/usr/local/libexec/claude-vmm
. $VL_DIR/gettone-lib.sh	# la SORGENTE della libreria installata (parere Opus «wrapper di root» par. 2.2e)
O=${1:?cartella}; case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac; [ -e "$O" ] && exit 2; mkdir -p "$O" || exit 2
U=$(id -u); ORA=1793500000; S=$(printf 'a%.0s' $(seq 64)); S2=$(printf 'b%.0s' $(seq 64))
nok=0; nko=0
ok() { nok=$((nok+1)); echo "  ok      $*"; }; no() { nko=$((nko+1)); echo "  ERRATO  $*"; }
g() {	# g <nome> <contenuto> [permessi]
	printf '%s' "$2" > "$O/$1"; chmod ${3:-644} "$O/$1"
}
BUONO="gettone 1
creato $((ORA-100))
scade $((ORA+3600))
elenco $S
passi scambio,distruggi
sequenza A,As,B stadio 10
"
caso() {	# caso <nome> <atteso 0|1> <operazione> <motivo atteso o -> [sha] [ora] [uid]
	m=$(gettone_valido "$O/$1" "$3" "${5:-$S}" "${6:-$ORA}" "${7:-$U}"); r=$?
	if [ $r = $2 ] && { [ "$4" = - ] || echo "$m" | grep -q -- "$4"; }; then ok "$1 ($3): $m"; else no "$1 ($3) rc=$r: $m (atteso $2, '$4')"; fi
}
g buono "$BUONO"
caso buono 0 scambio "gettone valido"
caso buono 0 distruggi "gettone valido"
caso buono 1 ombra "non autorizzata"
caso buono 1 avvio-vm "non autorizzata"
caso buono 1 scambio "SCADUTO" "$S" $((ORA+3600))
caso buono 1 scambio "creato nel futuro" "$S" $((ORA-200))
caso buono 1 scambio "cambiato dopo il gettone" "$S2"
caso buono 1 scambio "uid" "$S" "$ORA" 0
caso assente 1 scambio "assente"
ln -s "$O/buono" "$O/link"; caso link 1 scambio "assente"
g scrivibile "$BUONO" 666; caso scrivibile 1 scambio "scrivibile"
g gruppo "$BUONO" 664; caso gruppo 1 scambio "scrivibile"
g riga_in_piu "${BUONO}passi ombra
"; caso riga_in_piu 1 scambio "righe"
g chiave_ripetuta "$(echo "$BUONO" | sed 's/^sequenza .*/passi ombra/')
"; caso chiave_ripetuta 1 ombra "ripetuta"
g lungo "$(echo "$BUONO" | sed "s/^scade .*/scade $((ORA+50000))/")
"; caso lungo 1 scambio "durata"
g versione "$(echo "$BUONO" | sed 's/^gettone 1/gettone 2/')
"; caso versione 1 scambio "versione"
g data "$(echo "$BUONO" | sed 's/^scade .*/scade domani/')
"; caso data 1 scambio "non numeriche"
g sha_corto "$(echo "$BUONO" | sed 's/^elenco .*/elenco abc/')
"; caso sha_corto 1 scambio "malformato"
g op_ignota "$(echo "$BUONO" | sed 's/^passi .*/passi scambio,tutto/')
"; caso op_ignota 1 scambio "sconosciuta"
g sottostringa "$(echo "$BUONO" | sed 's/^passi .*/passi scambiox/')
"; caso sottostringa 1 scambio "sconosciuta"
echo "SUMMARY: $nok ok, $nko errati"
[ $nko = 0 ]
