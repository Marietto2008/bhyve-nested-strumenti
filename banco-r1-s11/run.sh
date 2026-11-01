#!/bin/sh
# run.sh -- Claude 01/11/2026, P3 stadio 11 (parere #158 R1). Estrae le funzioni VERE dal vmm.c del clone dello
# stadio 11, compila ed esegue banco-r1, poi i mutanti (ciascuno deve far fallire il controllo indicato).
#   sudo -u collaudo sh run.sh <cartella nuova in collaudi>
set -u
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/nested-work
B=$W/banco-r1-s11
E=$W/logs/h2mmio-ptphold-read-20261030/estrai-fn.sh
S=${S11:-$W/freebsd-s11-nested}/sys/amd64/vmm/vmm.c
O=${1:?cartella}; case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste"; exit 2; }
mkdir -p "$O" || exit 2
CC="cc -std=gnu11 -O1 -Wall -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable"
sh $E $S vcpu_init vm_fatal_latch vm_handle_inst_emul vm_restart_instruction vm_segnala_conteso vm_run > $O/fn.inc
grep -q '#error' $O/fn.inc && { echo "estrazione fallita"; exit 1; }
grep -q 'vcpu->gla2gpa_conteso = false;' $O/fn.inc || { echo "l'estratto non e' lo stadio 11"; exit 1; }
nf=0
prova() {	# prova <nome> <funzioni>
	mkdir -p $O/$1 && cp $B/banco-r1.c $B/stub.h $O/$1/ && cp $2 $O/$1/funzioni.inc
	$CC -I$O/$1 -o $O/$1/banco $O/$1/banco-r1.c > $O/$1/cc.txt 2>&1 || { echo "COMPILAZIONE $1 FALLITA"; head -8 $O/$1/cc.txt; return 2; }
	$O/$1/banco "s11-$1" > $O/$1.txt 2>&1
}
prova vero $O/fn.inc; r=$?
cat $O/vero.txt
[ $r = 0 ] || nf=$((nf+1))
mut() {	# mut <nome> <caso che deve prenderlo> <vecchio> <nuovo>
	python3 -c "
import sys
s=open('$O/fn.inc').read(); a=sys.argv[1]; b=sys.argv[2]
assert s.count(a)==1, 'punto del mutante assente o ripetuto'
open('$O/mut-$1.inc','w').write(s.replace(a,b))" "$3" "$4" || { echo "  ERRATO  mutante $1 non generato"; nf=$((nf+1)); return; }
	prova mut-$1 $O/mut-$1.inc; r=$?
	if [ $r = 1 ] && grep -q "ERRATO  $2" $O/mut-$1.txt; then echo "  ok      mutante $1 preso da $2"
	else echo "  ERRATO  mutante $1 NON preso da $2 (rc $r: $(grep ERRATO $O/mut-$1.txt | head -1))"; nf=$((nf+1)); fi
}
mut senza_conversione R1c '		vme->exitcode = VM_EXITCODE_BOGUS;
		vme->inst_length = 0;
	} else
		conteso = false;' '		(void)0;
	} else
		conteso = false;'
mut segnale_ignorato R1c '	vcpu->gla2gpa_conteso = true;' '	(void)vcpu;'
mut conteso_azzera_i_cicli R1d '	if (!conteso)
		nested_loops = 0;' '	nested_loops = 0;'
mut flag_non_spento R1e '	vcpu->gla2gpa_conteso = false;
' ''
mut conversione_di_ogni_uscita R1f '	if (conteso && error == 0 && vme->exitcode == VM_EXITCODE_NESTED) {' '	if (conteso && error == 0) {'
echo "banco R1 stadio 11: errori $nf"
[ $nf = 0 ]
