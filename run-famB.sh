#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-famB.sh.non-conforme
echo "INERTE: run-famB.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-famB.sh.non-conforme" >&2; exit 4
# Claude 23/10/2026 -- parere #37 §3/§6: la famiglia B dei gestori INVEPT con la sonda
# leggera dtrace/invB.d, 4 VP veri, make -j4, vept_keep=1, vept_scan_retries=2 (baseline
# sperimentale a 4 VP), verifica HPA spenta. Memoria dell'host: vmstat 1 e swapinfo ogni
# 30 s per tutta la corsa.
B=/mnt/linuxulator2/vm/wsl2/fbsd
G=/usr/bin/grep
T=$(date +%Y%m%d-%H%M)
echo "######## FAMB: 4 VP, -j4, retry 2 $(date +%T)"
echo "== host prima: $(swapinfo -h | tail -1)"
vmstat -w 1 > $B/logs/famB-vmstat-$T.txt &
VS=$!
( while :; do echo "$(date +%T) $(swapinfo -k | tail -1)"; sleep 30; done ) > $B/logs/famB-swap-$T.txt &
SW=$!
sudo -n dtrace -s $B/dtrace/invB.d -o $B/logs/invB-$T.txt 2>$B/logs/invB-$T.err &
sleep 3
VMS=12-Windows-11-vm12-senza-gpu-4core KBS=kbuild4.sh sh $B/run-b1win.sh 1 0 FAMB-r2 2 2>&1 | $G -E "topologia|^real|kernel rc|bhyve CPU|spegnimento|NON|USCITO|retry_2_success|retry_exhausted|zapped_race|faults_l0"
sudo -n pkill -TERM -f "invB.d"
kill $VS $SW
echo "== host dopo: $(swapinfo -h | tail -1)"
echo "######## FINE $(date +%T)"
