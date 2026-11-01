#!/bin/sh
# mutanti-verdetto-ombra.sh -- Claude 31/10/2026, parere Opus C1. Un mutante per ogni regola del contratto dell'ombra e
# del modo in opnd-verdetto.py; test-verdetti.py, puntato sul verdetto mutato, deve FALLIRE. Uso: <cartella nuova>
set -u
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh	# 31/10/2026 (parere Opus sull'incidente): solo utente collaudo, sudo irraggiungibile
B=/mnt/linuxulator2/vm/nested-work; O=${1:?cartella}
[ -e "$O" ] && { echo "$O esiste"; exit 2; }
mkdir -p "$O"; nf=0
mut() {	# mut <nome> <caso che DEVE prenderlo> <vecchio> <nuovo>  (parere Opus sull'incidente par. 3.4: il MOTIVO)
	MN=$1; MC=$2; shift 2; set -- "$MN" "$@"
	/usr/local/bin/python3 - "$B/opnd-verdetto.py" "$O/$1.py" "$2" "$3" <<'FINE_PY_MV'
import sys
s = open(sys.argv[1]).read()
if s.count(sys.argv[3]) != 1: sys.exit('testo assente o non unico: ' + sys.argv[3][:60])
open(sys.argv[2], 'w').write(s.replace(sys.argv[3], sys.argv[4]))
FINE_PY_MV
	[ -s "$O/$1.py" ] || { echo "  ERRATO  mutante $1 non generato"; nf=$((nf+1)); return; }
	sed "s|B + '/opnd-verdetto.py'|'$O/$1.py'|" "$B/test-verdetti.py" > "$O/tv-$1.py"
	if /usr/local/bin/python3 "$O/tv-$1.py" "$O/out-$1" > "$O/$1.txt" 2>&1; then echo "  ERRATO  mutante $1 NON preso"; nf=$((nf+1))
	elif grep -qE "^ *ERRATO +opnd $MC " "$O/$1.txt"; then echo "  ok      mutante $1 preso dal suo caso $MC (tutti: $(grep -E '^ *ERRATO' $O/$1.txt | grep -o 'opnd [a-z0-9_]*' | tr '\n' ' '))"
	else echo "  ERRATO  mutante $1 preso, ma NON dal suo caso $MC: $(grep -E '^ *ERRATO' $O/$1.txt | grep -o 'opnd [a-z0-9_]*' | tr '\n' ' ')"; nf=$((nf+1)); fi
}
mut ombra_apertura ombra_apertura_0 "		if ap[0] != '1':" "		if 0:"
mut ombra_chiusura ombra_chiusura_1 "		if ch[0] != '0':" "		if 0:"
mut ombra_ingressi ombra_senza_ingressi "		if shv <= 0:" "		if 0:"
mut ombra_spento ombra_lasciata_spenta "		if spento:
			inc.append" "		if 0:
			inc.append"
mut ombra_guasto ombra_guasto_vm_fermata "		if guasto:" "		if 0:"
mut normale_valori normale_apertura_1 "		if ap[0] != '0' or ch[0] != '0':" "		if 0:"
mut normale_ingressi normale_con_ingressi "		if shv != 0:" "		if 0:"
mut normale_messaggi normale_messaggio_ombra "		if spento or guasto:" "		if 0:"
mut modo_piano f4_con_modo_esegui "	elif (piano == 'F4') != (modo == '--esegui-d') or" "	elif 0 and"
mut manifest_righe manifest_senza_riga_chiusura "	if len(ap) != 1 or len(ch) != 1:" "	if 0:"
mut etichetta_sonde v9_etichetta_diversa "	elif sd and not re.search(" "	elif 0 and not re.search("
echo "mutanti del verdetto: errori $nf"
[ $nf = 0 ]
