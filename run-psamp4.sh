#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-psamp4.sh.non-conforme
echo "INERTE: run-psamp4.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-psamp4.sh.non-conforme" >&2; exit 4
# Claude 24/10/2026 -- parere #39 §6.1/§7.1: tempo dei thread vCPU per stack, SOLO
# campionamento (dtrace/pmapsamp.d, profile-199, stack(12)), niente lockstat ne' ping, 4 VP veri, make -j4, vept_keep=1, vept_scan_retries=2 (baseline
# sperimentale a 4 VP), verifica HPA spenta. Memoria dell'host: vmstat 1 e swapinfo ogni
# 30 s per tutta la corsa.
B=/mnt/linuxulator2/vm/wsl2/fbsd
G=/usr/bin/grep
T=$(date +%Y%m%d-%H%M)
echo "######## PSAMP4-r2: 4 VP, -j4, retry 2 $(date +%T)"
echo "== host prima: $(swapinfo -h | tail -1)"
vmstat -w 1 > $B/logs/psamp4-vmstat-$T.txt &
VS=$!
( while :; do echo "$(date +%T) $(swapinfo -k | tail -1)"; sleep 30; done ) > $B/logs/psamp4-swap-$T.txt &
SW=$!
# parere #40 §9: la guardia WSL in Windows si aggiorna a VM pronta e va in pausa appena la
# compilazione e' partita (kbuild.log con "make -j4"); si riprende a fine corsa
( w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR marietto@win11 "$@" 2>&1; }
  k=0; until w "echo pronto" | $G -q pronto; do sleep 10; k=$((k+1)); [ $k -gt 90 ] && exit 1; done
  sh $B/guardia-win.sh aggiorna > /dev/null; sh $B/guardia-win.sh pausa-dopo kbuild.log "make -j4" ) > $B/logs/psamp4-guardia-$T.txt 2>&1 &
sudo -n dtrace -s $B/dtrace/pmapsamp.d -o $B/logs/psamp4-$T.txt 2>$B/logs/psamp4-$T.err &
sleep 3
VMS=12-Windows-11-vm12-senza-gpu-4core KBS=kbuild4.sh sh $B/run-b1win.sh 1 0 PSAMP4-r2 2 2>&1 | $G -E "topologia|^real|kernel rc|bhyve CPU|spegnimento|NON|USCITO|retry_2_success|retry_exhausted|zapped_race|faults_l0"
sudo -n pkill -TERM -f "pmapsamp.d"
kill $VS $SW
sh $B/guardia-win.sh riprendi >> $B/logs/psamp4-guardia-$T.txt 2>&1
echo "== host dopo: $(swapinfo -h | tail -1)"
echo "######## FINE $(date +%T)"
