#!/bin/sh
# mutanti.sh -- Claude 31/10/2026, stadio 10 (R9 + R9c). Ogni mutante modifica UNA regola di vmm_instruction_emul.c
# dell'albero dato (in una copia) e il banco deve fallire. Uso: mutanti.sh <albero> <cartella di uscita nuova>
set -u
. /mnt/linuxulator2/vm/wsl2/linux/collaudo-preambolo.sh	# 31/10/2026 (parere Opus sull'incidente): solo utente collaudo, sudo irraggiungibile
D=$(cd "$(dirname "$0")" && pwd); T=$1; O=$2
[ -e "$O" ] && { echo "$O esiste"; exit 2; }
mkdir -p "$O"; nf=0
mut() {	# mut <nome> <vecchio> <nuovo>
	mkdir -p "$O/$1/sys/amd64/vmm"
	/usr/local/bin/python3 - "$T/sys/amd64/vmm/vmm_instruction_emul.c" "$O/$1/sys/amd64/vmm/vmm_instruction_emul.c" "$2" "$3" <<'FINE_PY_MUT_R9C'
import sys
s = open(sys.argv[1]).read()
if s.count(sys.argv[3]) != 1: sys.exit('testo del mutante assente o non unico: ' + sys.argv[3][:60])
open(sys.argv[2], 'w').write(s.replace(sys.argv[3], sys.argv[4]))
FINE_PY_MUT_R9C
	[ -s "$O/$1/sys/amd64/vmm/vmm_instruction_emul.c" ] || { echo "  ERRATO  mutante $1: non generato"; nf=$((nf+1)); return; }
	if sh "$D/run.sh" "$O/$1" "$O/out-$1" > "$O/$1.txt" 2>&1; then echo "  ERRATO  mutante $1 NON preso"; nf=$((nf+1))
	else echo "  ok      mutante $1 preso: $(grep -m1 '  ERRATO ' $O/$1.txt | sed 's/^ *ERRATO //' | cut -c1-90)"; fi
}
mut piatto_non_esente '} else if (!(desc->base == 0 && desc->limit == 0xffffffff) &&' '} else if (1 &&'
mut expand_down_minore 'if (first <= desc->limit || last > top)' 'if (first < desc->limit || last > top)'
mut top_sempre_4g 'top = SEG_DESC_DEF32(desc->access) ? 0xffffffff : 0xffff;' 'top = 0xffffffff;'
mut primo_contro_top 'if (first <= desc->limit || last > top)' 'if (first <= desc->limit || first > top)'
mut r9c_ss_solo_protetto '	error = vm_get_seg_desc(vcpu, VM_REG_GUEST_SS, &ss_desc);
	KASSERT(error == 0, ("%s: error %d getting SS descriptor",
	    __func__, error));

	/*
	 * From "Address-Size' '	/*
	 * From "Address-Size'
echo "mutanti: errori $nf"
[ $nf = 0 ]
