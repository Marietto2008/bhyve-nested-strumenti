#!/bin/sh
# run.sh -- Claude 30/10/2026, parere #158 B4d (R3). Estrae le funzioni VERE dal clone nested, compila il banco,
# lo esegue (atteso: il comportamento ATTUALE, cioe' il salto silenzioso su EFAULT), poi applica un mutante che
# cambia il ramo EFAULT e verifica che il banco se ne accorga. Il clone base non ha vmx_nested.c: R3 non vi esiste.
# Uso: run.sh <cartella di uscita>
W=/mnt/linuxulator2/vm/wsl2/linux
B=$W/banco-r3
T=$W/freebsd-ripfix-nested/sys/amd64/vmm
O=${1:?cartella}
mkdir -p "$O" || exit 1
CC="cc -std=gnu11 -Wall -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable"
nf=0
[ -e $W/freebsd-ripfix-base/sys/amd64/vmm/intel/vmx_nested.c ] && { echo "il base HA vmx_nested.c: rivedere"; nf=$((nf+1)); }
grep -q 'vcpu->nextrip = vme->rip + vme->inst_length;' $T/vmm.c || { echo "passo di vm_run assente"; nf=$((nf+1)); }
{ python3 $B/estrai.py $T/vmm.c vm_set_register vm_restart_instruction &&
  python3 $B/estrai.py $T/intel/vmx_nested.c nested_vmfail_invalid nested_advance_rip nested_canonical \
      nested_operand_gpa_at nested_operand_gpa nested_read_operand_u64 nested_vmptrst nested_vmclear nested_invvpid
} > "$O/fn.inc" || { echo "estrazione fallita"; grep '#error' "$O/fn.inc"; exit 2; }

prova() {	# prova <nome> <file funzioni> <atteso>
	mkdir -p "$O/$1"
	cp "$B/stub.h" "$B/banco.c" "$O/$1/"; cp "$2" "$O/$1/funzioni.inc"
	$CC -I"$O/$1" -o "$O/$1/banco" "$O/$1/banco.c" > "$O/$1/cc.txt" 2>&1 || { echo "COMPILAZIONE FALLITA $1"; head -20 "$O/$1/cc.txt"; return 2; }
	"$O/$1/banco" "$1" "$3" > "$O/$1/esito.txt" 2>&1
}
prova nested "$O/fn.inc" attuale; r=$?
cat "$O/nested/esito.txt"; [ $r = 0 ] || nf=$((nf+1))

# mutante: il ramo EFAULT riparte l'istruzione (nextrip = rip) invece di lasciarla saltare. Il banco con
# l'atteso "attuale" DEVE fallire sulle righe EFAULT e SOLO su quelle.
python3 - "$O/fn.inc" "$O/mut.inc" <<'FINE_PY_MUT_R3'
import sys
s = open(sys.argv[1]).read()
v = '''	if (vm_gla2gpa(vcpu->vcpu, &paging, gla, prot, gpa, &fault) != 0 || fault)
		return (-1);'''
assert s.count(v) == 1, 'testo del mutante assente'
s = s.replace(v, '''	if (vm_gla2gpa(vcpu->vcpu, &paging, gla, prot, gpa, &fault) != 0) {
		vm_restart_instruction(vcpu->vcpu);
		return (-1);
	}
	if (fault)
		return (-1);''')
open(sys.argv[2], 'w').write(s)
FINE_PY_MUT_R3
[ -s "$O/mut.inc" ] || { echo "mutante non generato"; exit 2; }
prova mutante "$O/mut.inc" attuale; r=$?
m=$(grep -c '  ERRATO' "$O/mutante/esito.txt")
me=$(grep '  ERRATO' "$O/mutante/esito.txt" | grep -c 'EFAULT')
if [ $r = 1 ] && [ "$m" = 3 ] && [ "$me" = 3 ]; then echo "  ok      mutante preso, solo sulle 3 righe EFAULT:"; grep '  ERRATO' "$O/mutante/esito.txt"
else echo "  ERRATO  mutante: uscita $r, righe errate $m (EFAULT $me)"; cat "$O/mutante/esito.txt"; nf=$((nf+1)); fi
echo "banco R3: errori $nf"
[ $nf = 0 ]
