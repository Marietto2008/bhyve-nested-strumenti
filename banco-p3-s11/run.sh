#!/bin/sh
# run.sh -- Claude 01/11/2026, P3 stadio 11. Estrae le funzioni VERE dal clone dello stadio 11, compila ed esegue il
# banco, poi i mutanti (ciascuno deve essere preso da un caso). Come utente collaudo:
#   sudo -u collaudo sh run.sh <cartella nuova in collaudi>
set -u
. /mnt/linuxulator2/vm/wsl2/fbsd/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/wsl2/fbsd
B=$W/banco-p3-s11
E=$W/logs/h2mmio-ptphold-read-20261030/estrai-fn.sh
S=${S11:-$W/freebsd-s11-nested}/sys/amd64/vmm/vmm_instruction_emul.c
O=${1:?cartella}; case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste"; exit 2; }
mkdir -p "$O" || exit 2
CC="cc -std=gnu11 -O1 -Wall -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable -Wno-visibility"
{ sed -n '/^#define[[:space:]]PTP_PEND_MAX/,/^};/p' $S; sh $E $S vie_canonical_check pf_error_code ptp_release ptp_hold ptp_ad_write_check ptp_pend_add ptp_commit _vm_gla2gpa; } > $O/fn.inc
sh $E $S vm_gla2gpa vm_gla2gpa_budget >> $O/fn.inc
sh $E ${S%/*}/vmm.c vm_copy_teardown _vm_copy_setup >> $O/fn.inc
grep -q '#error' $O/fn.inc && { echo "estrazione fallita"; exit 1; }
grep -q 'bool \*conteso' $O/fn.inc || { echo "l'estratto non e' lo stadio 11 (manca conteso)"; exit 1; }
nf=0
prova() {	# prova <nome> <funzioni> -> esito in $O/<nome>.txt
	mkdir -p $O/$1 && cp $B/banco.c $B/stub.h $O/$1/ && cp $2 $O/$1/funzioni.inc
	$CC -I$O/$1 -o $O/$1/banco $O/$1/banco.c -lpthread > $O/$1/cc.txt 2>&1 || { echo "COMPILAZIONE $1 FALLITA"; head -5 $O/$1/cc.txt; return 2; }
	$O/$1/banco "s11-$1" > $O/$1.txt 2>&1
}
prova vero $O/fn.inc; r=$?
cat $O/vero.txt
[ $r = 0 ] || nf=$((nf+1))
mut() {	# mut <nome> <caso che deve prenderlo> <vecchio> <nuovo>
	python3 -c "
import sys
s=open('$O/fn.inc').read(); a=sys.argv[1]; b=sys.argv[2]
assert s.count(a)==1, 'punto del mutante assente'
open('$O/mut-$1.inc','w').write(s.replace(a,b))" "$3" "$4" || { echo "  ERRATO  mutante $1 non generato"; nf=$((nf+1)); return; }
	prova mut-$1 $O/mut-$1.inc; r=$?
	if [ $r != 0 ] && grep -q "ERRATO  $2" $O/mut-$1.txt; then echo "  ok      mutante $1 preso da $2"
	else echo "  ERRATO  mutante $1 NON preso da $2 (rc $r: $(grep ERRATO $O/mut-$1.txt | head -1))"; nf=$((nf+1)); fi
}
mut senza_limite B1 '		if (conteso != NULL && gla2gpa_restart_max != 0 &&' '		if (0 && conteso != NULL && gla2gpa_restart_max != 0 &&'
mut limite_anche_legacy L1 '		if (conteso != NULL && gla2gpa_restart_max != 0 &&
		    retries - 1 > gla2gpa_restart_max) {
			atomic_add_long(&gla2gpa_restart_capped, 1);
			*conteso = true;' '		if (gla2gpa_restart_max != 0 &&
		    retries - 1 > gla2gpa_restart_max) {
			atomic_add_long(&gla2gpa_restart_capped, 1);
			if (conteso != NULL) *conteso = true;'
mut codifica_respinta B1 '			*conteso = true;
			retval = 0;
			goto done;' '			if (conteso) *conteso = true;
			vm_restart_instruction(vcpu);
			goto fault;'
mut contatore_fermo B1 '			atomic_add_long(&gla2gpa_restart_capped, 1);' '			(void)0;'
mut fuori_di_uno B3 '		    retries - 1 > gla2gpa_restart_max) {' '		    retries - 1 >= gla2gpa_restart_max) {'
mut fuori_di_uno_largo B4 '		    retries - 1 > gla2gpa_restart_max) {' '		    retries - 1 > gla2gpa_restart_max + 1) {'
mut limite_zero_attivo B7 '		if (conteso != NULL && gla2gpa_restart_max != 0 &&' '		if (conteso != NULL &&'
mut copia_tiene_pagine C1 '			if (error == 0 && *fault == 0 && *conteso)
				return (0);' '			if (0)
				return (0);'
echo "banco P3 stadio 11: errori $nf"
[ $nf = 0 ]
