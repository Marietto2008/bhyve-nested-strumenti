#!/bin/sh
# Claude 21/10/2026 -- B1 (parere #28), passo 6: regressione kvm-unit-tests
# completa con hw.vmm.vmx.vept_keep=1 e poi =0, stesso modulo. Uso: sudo sh run-regr.sh
B=/mnt/linuxulator2/vm/wsl2/fbsd; N=$B/freebsd-nested/tools/nested
O=$B/logs/regr-$(date +%Y%m%d-%H%M); mkdir -p $O
for k in 1 0; do
	sysctl hw.vmm.vmx.vept_keep=$k hw.vmm.vmx.vept_verify_hpa=$k >/dev/null
	sysctl hw.vmm.vmx | grep -E "vept_(keep|memgen|stale|verify)" > $O/ctr-keep$k.prima
	for l in f1 f2a f2b f2c invept immexit persist efersave; do
		sh $N/kut-run.sh --nested $N/kut-$l.list 2>&1 | grep -E '^  [a-zA-Z0-9_]+ ' >> $O/keep$k.txt
	done
	sh $N/kut-run.sh $N/kut-ioapic.list 2>&1 | grep -E '^  [a-zA-Z0-9_]+ ' >> $O/keep$k.txt
	sysctl hw.vmm.vmx | grep -E "vept_(keep|memgen|stale|verify)" > $O/ctr-keep$k.dopo
	ls /dev/vmm 2>/dev/null | grep -v '^vm0' | while read v; do bhyvectl --vm=$v --destroy; done
done
sysctl hw.vmm.vmx.vept_keep=0 hw.vmm.vmx.vept_verify_hpa=0 >/dev/null
awk '{print $1, $2}' $O/keep1.txt > $O/v1; awk '{print $1, $2}' $O/keep0.txt > $O/v0
echo "keep=1: $(awk '{print $2}' $O/v1 | sort | uniq -c | tr '\n' ' ')"
echo "keep=0: $(awk '{print $2}' $O/v0 | sort | uniq -c | tr '\n' ' ')"
echo "differenze (keep0 | keep1):"; diff $O/v0 $O/v1 && echo "  nessuna"
paste $O/ctr-keep1.prima $O/ctr-keep1.dopo | awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-34s %+d\n", $1, d}'
echo "OUTPUT $O"
