#!/bin/sh
# Claude 25/10/2026 -- parere #48 §6 e §10 (passi 04-05): kvm-unit-tests del TLB dell'L2 (lista
# kut-vpid.list, piu' eventuali altre liste) sul modulo CARICATO, con migrazione forzata opzionale e
# shadow VMCS opzionale. Nessun nuovo modulo, nessun riavvio.
#   M=1  migratore: i thread del QEMU dei test alternati fra le CPU 6 e 7 ogni P secondi
#   SH=1 shadow VMCS + verifica (nested_shadow_vmcs=1, nested_shadow_verify=1) e sonda migrapull.d
# uso: sudo -n env M=0|1 SH=0|1 [P=0.005] sh run-kutvpid.sh <etichetta> [liste...]
E=${1:?etichetta}; shift
B=/mnt/linuxulator2/vm/wsl2/linux; N=$B/freebsd-nested/tools/nested
LISTE=${*:-vpid}
: "${M:=0}" "${SH:=0}" "${P:=0.005}" "${TR:=-}" "${OFF:=-}"
O=$B/logs/kutvpid-$E-$(date +%Y%m%d-%H%M); mkdir -p "$O"
foto() { { sysctl hw.vmm.vmx | /usr/bin/grep -E "\.nested_(sh|shadow)|vpid"; } > "$O/$1"; }
sysctl hw.vmm.vmx.nested_shadow_vmcs=$SH hw.vmm.vmx.nested_shadow_verify=$SH > /dev/null
# TR/OFF (parere #50): tracciamento VPID e ripiego di prova, solo col modulo 22ad8106199e o successivi;
# '-' = non toccare (il modulo 19fc4ebf6189 non ha questi interruttori)
[ "$TR" != "-" ] && sysctl hw.vmm.vmx.nested_vpid_track=$TR hw.vmm.vmx.nested_vpid12_flush=0 > /dev/null
[ "$OFF" != "-" ] && sysctl hw.vmm.vmx.nested_vpid_test_off=$OFF > /dev/null
echo "etichetta $E M=$M P=$P SH=$SH TR=$TR OFF=$OFF modulo $(sha256 -q /boot/kernel/vmm-restore.ko | cut -c1-8) liste=$LISTE inizio $(date +%T)" | tee "$O/esiti.txt"
foto sysctl-prima.txt
if [ "$M" = 1 ]; then
	sh $B/kutvpid/migratore.sh 6 7 "$P" "$O/migratore.txt" &
	MPID=$!
	CPUS=6,7
else
	CPUS=6
fi
for L in $LISTE; do
	if [ "$SH" = 1 ]; then
		dtrace -q -s $B/dtrace/19fc4ebf6189/migrashadow.d -o "$O/migrashadow-$L.txt" \
		    -c "env TEST_CPUS=$CPUS sh $B/kutvpid/kut-run.sh --nested $N/kut-$L.list" > "$O/kut-$L.out" 2>&1
	else
		env TEST_CPUS=$CPUS sh $B/kutvpid/kut-run.sh --nested $N/kut-$L.list > "$O/kut-$L.out" 2>&1
	fi
	/usr/bin/grep -E " (PASS|FAIL|TIMEOUT|ERR)" "$O/kut-$L.out" | sed "s/^/$L /" >> "$O/esiti.txt"
	dmesg | tail -3 | /usr/bin/grep -i "nested shadow\|panic" && echo "!!! messaggio dal kernel dopo $L" | tee -a "$O/esiti.txt"
done
[ -n "$MPID" ] && kill $MPID 2>/dev/null
foto sysctl-dopo.txt
sysctl hw.vmm.vmx.nested_shadow_vmcs=0 hw.vmm.vmx.nested_shadow_verify=0 > /dev/null
[ "$TR" != "-" ] && sysctl hw.vmm.vmx.nested_vpid_track=0 > /dev/null
[ "$OFF" != "-" ] && sysctl hw.vmm.vmx.nested_vpid_test_off=0 > /dev/null
# VM dei kvm-unit-tests rimaste senza processo (QEMU a volte non le distrugge)
for v in $(ls /dev/vmm 2>/dev/null); do
	[ -z "$(fuser /dev/vmm/$v 2>/dev/null)" ] && bhyvectl --vm=$v --destroy && echo "distrutta VM orfana $v" >> "$O/esiti.txt"
done
echo "fine $(date +%T)" >> "$O/esiti.txt"
cat "$O/esiti.txt"
echo "OUTPUT $O"
