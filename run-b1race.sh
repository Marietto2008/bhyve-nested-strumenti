#!/bin/sh
# Claude 22/10/2026 -- B1 retry (parere #29 §7): corsa deterministica fra le passate.
# Uso: sudo sh run-b1race.sh   (log in logs/b1race-AAAAMMGG-HHMM)
B=/mnt/linuxulator2/vm/nested-work; N=$B/freebsd-nested/tools/nested
O=$B/logs/b1race-$(date +%Y%m%d-%H%M); mkdir -p $O
G=/usr/bin/grep
ctr() { sysctl hw.vmm.vmx | $G -E "vept_(scan|test_race_inj|leaves_zapped|keep_(partial|full)|stale)" | sed 's/^hw.vmm.vmx.//'; }
$G '^b1_race' $N/kut-b1.list > $O/race.list
prova() {	# prova <etichetta> <vept_test_race> <vept_scan_retries>
	sysctl hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_verify_hpa=1 hw.vmm.vmx.vept_test_race=$2 hw.vmm.vmx.vept_scan_retries=$3 >/dev/null
	ctr > $O/$1.prima
	sh $N/kut-run.sh --nested $O/race.list > $O/$1.kut 2>&1
	sysctl hw.vmm.vmx.vept_test_race=0 >/dev/null
	ctr > $O/$1.dopo
	s=$(/bin/ls -t $B/logs/kut-*-b1_race.serial | head -1); cp $s $O/$1.serial
	echo "== $1 (test_race=$2 retries=$3): $($G -E 'PASS|FAIL|TIMEOUT|ERR' $O/$1.kut | tail -1 | awk '{print $2}')"
	$G -E "^(PASS|FAIL)|B1RACE: fine" $O/$1.serial | sed 's/^/   /'
	/usr/bin/paste $O/$1.prima $O/$1.dopo | awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-38s %+d\n", $1, d}'
}
prova A-controllo   0 1
prova B-una-r0      1 0
prova C-una-r1      1 1
prova D-sempre-r1   2 1
prova E-sempre-r2   2 2
sysctl hw.vmm.vmx.vept_test_race=0 hw.vmm.vmx.vept_scan_retries=1 hw.vmm.vmx.vept_keep=0 hw.vmm.vmx.vept_verify_hpa=0 >/dev/null
echo "OUTPUT $O"
