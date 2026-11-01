#!/bin/sh
# run.sh -- Claude 30/10/2026, pareri #155/#156. Estrae le funzioni VERE dai due cloni, compila il banco P3, lo esegue;
# poi il MUTANTE della codifica respinta (#156 §3): l'oracolo del contratto deve rifiutarlo.
# Uso: run.sh <cartella di lavoro nuova>
W=/mnt/linuxulator2/vm/wsl2/fbsd
B=$W/banco-p3
E=$W/logs/h2mmio-ptphold-read-20261030/estrai-fn.sh
O=${1:?cartella}
[ -e "$O" ] && { echo "$O esiste"; exit 2; }
mkdir -p "$O" || exit 2
# #include "funzioni.inc" cerca PRIMA nella cartella del sorgente: si compila una COPIA di banco.c e stub.h dentro $O,
# cosi' l'unico funzioni.inc raggiungibile e' quello appena preparato (30/10: un funzioni.inc vecchio in banco-p3/
# aveva fatto compilare il base con le funzioni nested e il mutante con quelle originali)
cp $B/banco.c $B/stub.h $O/ || exit 2
CC="cc -std=gnu11 -O1 -Wall -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable -Wno-visibility"
nf=0
for t in base nested; do
	S=$W/freebsd-ripfix-$t/sys/amd64/vmm/vmm_instruction_emul.c
	if [ $t = nested ]; then
		{ sed -n '/^#define[[:space:]]PTP_PEND_MAX/,/^};/p' $S; sh $E $S vie_canonical_check pf_error_code ptp_release ptp_hold ptp_ad_write_check ptp_pend_add ptp_commit _vm_gla2gpa; } > $O/fn-$t.inc
	else
		sh $E $S vie_canonical_check pf_error_code ptp_release ptp_hold _vm_gla2gpa > $O/fn-$t.inc
	fi
	grep -q '#error' $O/fn-$t.inc && { echo "estrazione fallita: $t"; nf=$((nf+1)); continue; }
	cp $O/fn-$t.inc $O/funzioni.inc
	grep -q "^ptp_commit" $O/funzioni.inc; h=$?; [ $t = nested ] && [ $h != 0 ] && { echo "funzioni nested senza ptp_commit"; nf=$((nf+1)); }; [ $t = base ] && [ $h = 0 ] && { echo "funzioni base CON ptp_commit"; nf=$((nf+1)); }
	$CC -I$O -o $O/banco-$t $O/banco.c -lpthread > $O/cc-$t.txt 2>&1 || { echo "COMPILAZIONE $t FALLITA"; head $O/cc-$t.txt; nf=$((nf+1)); continue; }
	$O/banco-$t ripfix-$t contesa > $O/esito-$t.txt 2>&1 || nf=$((nf+1))
	tail -1 $O/esito-$t.txt
	# mutante: la codifica respinta, applicata al codice VERO del walk
	python3 - $O/fn-$t.inc $O/mut-$t.inc <<'FINE_PY_MUT_P3'
import sys
s = open(sys.argv[1]).read()
o = '\tif (retries++ > 0)\n\t\tmaybe_yield();\n'
assert s.count(o) == 1, 'punto del mutante assente'
open(sys.argv[2], 'w').write(s.replace(o, '\tif (retries++ > 0) {\n\t\tmaybe_yield();\n\t\tif (retries > 8) {\n\t\t\tvm_restart_instruction(vcpu);\n\t\t\tgoto fault;\n\t\t}\n\t}\n'))
FINE_PY_MUT_P3
	[ -s $O/mut-$t.inc ] || { echo "mutante $t non generato"; nf=$((nf+1)); continue; }
	cp $O/mut-$t.inc $O/funzioni.inc
	$CC -DMUTANTE_CODIFICA_RESPINTA -I$O -o $O/banco-mut-$t $O/banco.c -lpthread > $O/cc-mut-$t.txt 2>&1 || { echo "COMPILAZIONE mutante $t FALLITA"; nf=$((nf+1)); continue; }
	$O/banco-mut-$t ripfix-$t > $O/esito-mut-$t.txt 2>&1
	grep '^MUTANTE' $O/esito-mut-$t.txt
	# il mutante fa fallire S2 (ora torna) MA l'oracolo deve dire FAULT_SENZA_CAUSA: il controllo VERO del mutante passa
	if grep -q 'contratto FAULT_SENZA_CAUSA' $O/esito-mut-$t.txt && ! grep -q 'ERRATO  MUTANTE' $O/esito-mut-$t.txt; then
		echo "  ok      mutante $t: la codifica 'restart + fault=1 senza causa' e' RIFIUTATA dall'oracolo del contratto"
	else echo "  ERRATO  mutante $t non rifiutato"; nf=$((nf+1)); fi
done
echo "banco P3: errori $nf"
[ $nf = 0 ]
