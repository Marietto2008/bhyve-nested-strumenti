#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-d4check.sh.non-conforme
echo "INERTE: run-d4check.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-d4check.sh.non-conforme" >&2; exit 4
# Claude 25/10/2026 -- parere #52 §2: riconciliazione richieste differite / invalidazioni VPID02.
# Quattro prove (aggancio 0|200, CPU fissa|migrante) con la stessa suite breve; per ognuna i delta
# dei contatori VPID02 e gli errori dei test. Tracciamento SEMPRE acceso (il VPID02 e' suo).
B=/mnt/linuxulator2/vm/wsl2/fbsd
O=$B/logs/d4check-$(date +%Y%m%d-%H%M); mkdir -p "$O"
C="nested_vpid_d4_injected vpid02_req vpid02_req_coalesced vpid02_req_satisfied vpid02_req_dropped \
   vpid02_invvpid_first vpid02_invvpid_real_migration vpid02_invvpid_pending vpid01_invvpid_pending"
snap(){ for k in $C; do printf '%s=%s ' $k "$(sysctl -n hw.vmm.vmx.$k)"; done; }
prova(){	# prova <etichetta> <arm> <M>
	et=$1; arm=$2; m=$3
	sudo -n sysctl hw.vmm.vmx.nested_vpid_track=1 hw.vmm.vmx.nested_vpid_d4_arm=$arm >/dev/null
	A=$(snap)
	env M=$m SH=0 TR=- OFF=- P=0.005 sh $B/run-kutvpid.sh d4c-$et d4check > "$O/$et.out" 2>&1
	Bb=$(snap)
	sudo -n sysctl hw.vmm.vmx.nested_vpid_d4_arm=0 hw.vmm.vmx.nested_vpid_track=0 >/dev/null
	echo "== $et (arm=$arm M=$m)" | tee -a "$O/riconcilia.txt"
	echo "  PRIMA: $A" >> "$O/riconcilia.txt"
	echo "  DOPO:  $Bb" >> "$O/riconcilia.txt"
	echo "$A" > "$O/.a"; echo "$Bb" > "$O/.b"
	for k in $C; do
		pa=$(sed "s/.*$k=\([0-9]*\).*/\1/" "$O/.a"); pb=$(sed "s/.*$k=\([0-9]*\).*/\1/" "$O/.b")
		printf '  %-32s %10d\n' "$k" "$((pb-pa))" | tee -a "$O/riconcilia.txt"
	done
	fails=$(/usr/bin/grep -c "FAIL" "$O/$et.out" 2>/dev/null)
	echo "  esiti test: $(/usr/bin/grep -cE ' PASS ' "$O/$et.out") PASS, righe FAIL $fails" | tee -a "$O/riconcilia.txt"
	/usr/bin/grep -E "FAIL|TIMEOUT|ERR\(" "$O/$et.out" | /usr/bin/grep -v distrutta | sed 's/^/    /' | tee -a "$O/riconcilia.txt"
}
prova ctrl-fissa   0   0
prova d4-fissa     200 0
prova ctrl-migra   0   1
prova d4-migra     200 1
sudo -n sysctl hw.vmm.vmx.nested_vpid_track=0 hw.vmm.vmx.nested_vpid_d4_arm=0 >/dev/null
echo "D4CHECK-FINE $O" | tee -a "$O/riconcilia.txt"
