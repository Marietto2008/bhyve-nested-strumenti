#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-faseB.sh.non-conforme
echo "INERTE: run-faseB.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-faseB.sh.non-conforme" >&2; exit 4
# Claude 22/10/2026 -- parere #31: verifica HPA O(K x D) e fase B a 4 vCPU.
# vept_keep=1, vept_scan_retries=1, vept_verify_hpa=1 dove non detto altrimenti.
B=/mnt/linuxulator2/vm/nested-work; N=$B/freebsd-nested/tools/nested
O=$B/logs/faseB-$(date +%Y%m%d-%H%M); mkdir -p $O
G=/usr/bin/grep
ctr() { sysctl hw.vmm.vmx | $G -E "vept_|nested_" | sed 's/^hw.vmm.vmx.//'; }
dd() { /usr/bin/paste $1 $2 | awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-38s %d\n", $1, d}'; }
set_b1() { sudo -n sysctl hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_scan_retries=1 hw.vmm.vmx.vept_verify_hpa=$1 hw.vmm.vmx.vept_test_race=0 hw.vmm.vmx.vept_test_verify_corrupt=0 >/dev/null; }

echo "######## 1a. rilevatore della verifica HPA $(date +%T)"
set_b1 1; ctr > $O/rilev.prima
$G '^b1_persist' $N/kut-b1.list > $O/rilev.list
sudo -n sysctl hw.vmm.vmx.vept_test_verify_corrupt=1 >/dev/null
sudo -n sh $N/kut-run.sh --nested $O/rilev.list 2>&1 | $G -E "PASS|FAIL|TIMEOUT|ERR"
ctr > $O/rilev.dopo; dd $O/rilev.prima $O/rilev.dopo | $G -E "verify|zapped_other|full_fallbacks|t_verify"

echo "######## 1b. T1, persistenza, T2, generazione (run-b1kut.sh) $(date +%T)"
sudo -n sh $B/run-b1kut.sh 2>&1 | $G -E "^==|FAIL|verify_mismatch|stale"

echo "######## 1c. T2 a 4 LP $(date +%T)"
set_b1 1; ctr > $O/conc4.prima
$G '^b1_conc4' $N/kut-b1.list > $O/conc4.list
sudo -n sh $N/kut-run.sh --nested $O/conc4.list 2>&1 | $G -E "PASS|FAIL|TIMEOUT|ERR"
s=$(/bin/ls -t $B/logs/kut-*-b1_conc4.serial | head -1); cp $s $O/conc4.serial; $G -E "^(PASS|FAIL)" $s | sed 's/^/   /'
ctr > $O/conc4.dopo; dd $O/conc4.prima $O/conc4.dopo | $G -E "retry|race|alias|walkfull|walk_wipes|partial_invepts|full_fallbacks|verify"

echo "######## 1d. regressione breve $(date +%T)"
cat $N/kut-invept.list $N/kut-immexit.list $N/kut-persist.list $N/kut-f2a.list | $G -v '^#' > $O/breve.list
sudo -n sh $N/kut-run.sh --nested $O/breve.list 2>&1 | $G -E "PASS|FAIL|TIMEOUT|ERR"
sudo -n sysctl hw.vmm.vmx.vept_keep=0 hw.vmm.vmx.vept_verify_hpa=0 >/dev/null

for c in "kbuild.sh B4-j2" "kbuild4.sh B4-j4"; do
	set -- $c
	echo "######## 2. Windows 4 vCPU, $1 $(date +%T)"
	VMS=12-Windows-11-vm12-senza-gpu-4cpu KBS=$1 sh $B/run-b1win.sh 1 1 $2 1 2>&1 | $G -E "^real|kernel rc|bhyve CPU|cumulativo|spegnimento|OUTPUT|NON|USCITO|^   "
	sleep 30
done

echo "######## 3. 6 avvii a 4 vCPU $(date +%T)"
VMS=12-Windows-11-vm12-senza-gpu-4cpu sh $B/run-serie-b1.sh 6 2>&1 | tail -10
echo "######## FINE $(date +%T)"
