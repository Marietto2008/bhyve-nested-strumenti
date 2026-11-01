#!/bin/sh
# Claude 25/10/2026 -- parere #50 §9, passi 02-04 col modulo 22ad8106199e installato e caricato.
#   02  tutti gli interruttori a 0: i 81 kvm-unit-tests (run-kut-fase.sh, confronto con la fase 02
#       del 24/10) e le liste VPID vecchia e nuova col vCPU fermo; esiti attesi IDENTICI alla base
#       del 25/10 (vmx_pf_vpid_test e vmx_vpid_ctx_test compresi, che falliscono)
#   03  nested_vpid_track=1, nested_vpid12_flush=0, shadow spento, vCPU fermo: i 81 test e le liste VPID,
#       con la sonda vpid02vita.d sulla lista nuova
#   04  come 03 ma con migratore.sh fra le CPU 6 e 7
# Fra un passo e l'altro ci si ferma: il passo successivo lo lancia Claude dopo aver letto i risultati.
# uso: sudo -n sh run-vpid-fasi.sh 02|03|04
set -u
F=${1:?passo}
B=/mnt/linuxulator2/vm/wsl2/linux
O=$B/logs/vpidfase-$F-$(date +%Y%m%d-%H%M); mkdir -p "$O"
# il modulo CARICATO deve avere il tracciamento VPID: lo si riconosce
# dall'interruttore, senza legarsi a uno SHA preciso (22ad8106199e o successivi).
sysctl -n hw.vmm.vmx.nested_vpid_track > /dev/null 2>&1 || { echo "il modulo caricato non ha nested_vpid_track" | tee "$O/esito.txt"; exit 1; }
echo "modulo /boot: $(sha256 -q /boot/kernel/vmm-restore.ko | cut -c1-12)" > "$O/modulo.txt"
foto() { sysctl hw.vmm.vmx | /usr/bin/grep -E "vpid|nested_sh_faults|nested_sh_entry_after|vmcs02_host" > "$O/$1"; }
sysctl hw.vmm.vmx.nested_shadow_vmcs=0 hw.vmm.vmx.nested_shadow_verify=0 hw.vmm.vmx.nested_fast_field_validate=0 \
    hw.vmm.vmx.nested_vpid12_flush=0 hw.vmm.vmx.nested_vpid_test_off=0 > /dev/null
foto contatori-prima.txt
case $F in
02)	sysctl hw.vmm.vmx.nested_vpid_track=0 > /dev/null
	sh $B/run-kut-fase.sh vpid02-base > "$O/kut81.out" 2>&1
	d=$(tail -1 "$O/kut81.out" | awk '{print $2}')
	python3 $B/kut_confronta.py "$d" $B/logs/kutfase-02-tuttospento-20261024-1841 > "$O/confronto81.txt" 2>&1
	env M=0 SH=0 TR=0 sh $B/run-kutvpid.sh f02-vpid vpid vpidnew > "$O/vpid.out" 2>&1 ;;
03)	sysctl hw.vmm.vmx.nested_vpid_track=1 > /dev/null
	sh $B/run-kut-fase.sh vpid03-track > "$O/kut81.out" 2>&1
	d=$(tail -1 "$O/kut81.out" | awk '{print $2}')
	python3 $B/kut_confronta.py "$d" $B/logs/kutfase-02-tuttospento-20261024-1841 > "$O/confronto81.txt" 2>&1
	env M=0 SH=0 TR=1 sh $B/run-kutvpid.sh f03-vpid vpid > "$O/vpid.out" 2>&1
	sysctl hw.vmm.vmx.nested_vpid_track=1 > /dev/null
	dtrace -q -s $B/dtrace/22ad8106199e/vpid02vita.d -o "$O/vpid02vita.txt" \
	    -c "env M=0 SH=0 TR=1 sh $B/run-kutvpid.sh f03-vpidnew vpidnew" > "$O/vpidnew.out" 2>&1 ;;
04)	env M=1 SH=0 TR=1 P=0.005 sh $B/run-kutvpid.sh f04-migra vpid vpidnew > "$O/vpid.out" 2>&1 ;;
*)	echo "passo sconosciuto $F"; exit 2 ;;
esac
sysctl hw.vmm.vmx.nested_vpid_track=0 > /dev/null
foto contatori-dopo.txt
echo "FINE passo $F $(date +%T) -> $O" | tee "$O/esito.txt"
