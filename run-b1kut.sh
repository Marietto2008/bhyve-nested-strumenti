#!/bin/sh
# Claude 21/10/2026 -- B1 (parere #28 di Astra), passi 2-5: T1, T2, prova della
# generazione dei mapping e verifica HPA, tutti con hw.vmm.vmx.vept_keep=1.
# Per ogni test: contatori hw.vmm.vmx.vept_* prima e dopo, traccia b1keep.d.
# Uso: sudo sh run-b1kut.sh   (log in logs/b1kut-AAAAMMGG-HHMM)
B=/mnt/linuxulator2/vm/nested-work
N=$B/freebsd-nested/tools/nested
O=$B/logs/b1kut-$(date +%Y%m%d-%H%M); mkdir -p $O
BUMP=$O/memgen-bump
cc -Wall -o $BUMP $N/memgen-bump.c || exit 1
ctr() { sysctl hw.vmm.vmx | grep -E "vept_(keep|memgen|stale|shadow|verify)" | sed 's/^hw.vmm.vmx.//'; }
uno() {	# uno <etichetta> <riga della lista>
	echo "$2" > $O/$1.list
	ctr > $O/$1.prima
	dtrace -s $B/dtrace/b1keep.d -o $O/$1.dtrace 2>$O/$1.dtrace.err &
	DP=$!; sleep 3
	sh $N/kut-run.sh --nested $O/$1.list > $O/$1.kut 2>&1
	kill -TERM $DP; wait $DP 2>/dev/null
	ctr > $O/$1.dopo
	s=$(ls -t $B/logs/kut-*-$(echo "$2" | cut -d'|' -f1 | tr -d ' ').serial | head -1)
	cp $s $O/$1.serial
	echo "== $1: $(grep -E 'PASS|FAIL|TIMEOUT|ERR' $O/$1.kut | tail -1)"
	grep -E "^(PASS|FAIL)" $O/$1.serial | sed 's/^/   /'
	paste $O/$1.prima $O/$1.dopo | awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-34s %+d\n", $1, d}'
}
sysctl hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_verify_hpa=0 hw.vmm.vmx.vept_diag=0 >/dev/null
L=$N/kut-b1.list
uno T1-casi    "$(grep '^b1_casi' $L)"
uno T1-persist "$(grep '^b1_persist' $L)"
uno T2-conc    "$(grep '^b1_conc ' $L)"

# passo 4: generazione dei mapping, una sola iniezione durante il test
sysctl hw.vmm.nested_memgen_inject=1 >/dev/null
ctr > $O/memgen.prima
dtrace -s $B/dtrace/b1keep.d -o $O/memgen.dtrace 2>$O/memgen.dtrace.err &
DP=$!; sleep 3
grep '^b1_memgen' $L > $O/memgen.list
sh $N/kut-run.sh --nested $O/memgen.list > $O/memgen.kut 2>&1 &
KP=$!
i=0; s=""
while [ $i -lt 120 ]; do
	s=$(ls -t $B/logs/kut-*-b1_memgen.serial 2>/dev/null | head -1)
	[ -n "$s" ] && [ $s -nt $O/memgen.prima ] && grep -q "B1MG: pronto" $s && break
	sleep 1; i=$((i+1))
done
sleep 3
echo "iniezione: $($BUMP vm2 2>&1)" | tee $O/memgen.bump
wait $KP
kill -TERM $DP; wait $DP 2>/dev/null
sysctl hw.vmm.nested_memgen_inject=0 >/dev/null
ctr > $O/memgen.dopo
cp $s $O/memgen.serial
echo "== memgen: $(grep -E 'PASS|FAIL|TIMEOUT|ERR' $O/memgen.kut | tail -1)"
grep -E "^(PASS|FAIL)" $O/memgen.serial | sed 's/^/   /'
paste $O/memgen.prima $O/memgen.dopo | awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-34s %+d\n", $1, d}'

# passo 5: verifica HPA a campione su persistenza e concorrenza
sysctl hw.vmm.vmx.vept_verify_hpa=1 >/dev/null
uno V-persist "$(grep '^b1_persist' $L)"
uno V-conc    "$(grep '^b1_conc ' $L)"
sysctl hw.vmm.vmx.vept_verify_hpa=0 hw.vmm.vmx.vept_keep=0 >/dev/null
echo "OUTPUT $O"
