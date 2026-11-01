#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-serie.sh.non-conforme
echo "INERTE: run-serie.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-serie.sh.non-conforme" >&2; exit 4
# Claude 20/10/2026: serie di corse Windows 11 + Hyper-V (pareri #21/#22).
# uso: run-serie.sh <N>. Ogni corsa: avvio, desktop (explorer via SSH), wsl -d Debian,
# contatori, shutdown /s pulito. Nessun limite stretto: 15 min per il desktop, 5 per lo spegnimento.
N=${1:-3}
B=/mnt/linuxulator2/vm/wsl2/fbsd
T=$B/freebsd-nested/tools/nested
S=$B/logs/serie-$(date +%Y%m%d-%H%M); mkdir -p $S
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
sudo -n sysctl hw.vmm.vmx.diag_ud=1 >/dev/null
k=1
while [ $k -le $N ]; do
  R=$S/corsa$k; mkdir -p $R
  sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
  sudo -n dtrace -s $B/dtrace/win-serie.d -o $R/dtrace.txt 2>/dev/null &
  sleep 4
  sudo -n sh $T/12-Windows-11-vm12-senza-gpu > $R/script.log 2>&1 &
  i=0; while [ $i -lt 60 ] && [ ! -e /dev/vmm/vm0:12 ]; do sleep 1; i=$((i+1)); done
  t0=$(date +%s); esito=OK
  desk=-1; i=0
  while [ $i -lt 90 ]; do
    if ! pgrep -x bhyve >/dev/null; then esito="BHYVE-USCITO"; break; fi
    if nc -z -w 3 win11 22 2>/dev/null && w "tasklist /fi \"imagename eq explorer.exe\"" | grep -qi explorer; then desk=$(( $(date +%s) - t0 )); break; fi
    sleep 10; i=$((i+1))
  done
  [ $desk -lt 0 ] && [ "$esito" = OK ] && esito="NO-DESKTOP"
  wslr="-"
  if [ $desk -ge 0 ]; then
    sleep 60
    printf '%s' "-d Debian -u root -- uname -r" > $R/args.txt
    sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR $R/args.txt marietto@win11:'C:/claude/wsl-args.txt'
    w "del C:\\claude\\wsl-log.txt 2>nul & del C:\\claude\\o.txt 2>nul & schtasks /create /tn claude-wsl /tr \"powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn claude-wsl >nul"
    j=0; while [ $j -lt 40 ]; do w "type C:\\claude\\wsl-log.txt" | grep -q codice && break; sleep 10; j=$((j+1)); done
    sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR marietto@win11:'C:/claude/o.txt' $R/wsl-o.txt 2>/dev/null
    wslr=$(grep -o "microsoft-standard-WSL2" $R/wsl-o.txt 2>/dev/null || echo "NO")
    [ "$wslr" = NO ] && esito="${esito}+WSL-KO"
  fi
  for c in 0 1; do sudo -n bhyvectl --vm=vm0:12 --cpu=$c --get-stats 2>/dev/null | grep -E "VMfail|VMCS12|ingressi in L2" | sed "s/^/vcpu$c /"; done > $R/stats.txt
  w "shutdown /s /t 0" >/dev/null
  i=0; while [ $i -lt 300 ] && pgrep -x bhyve >/dev/null; do sleep 1; i=$((i+1)); done
  if pgrep -x bhyve >/dev/null; then esito="${esito}+NO-SPEGNIMENTO"; sudo -n kill -KILL $(pgrep -x bhyve); sleep 2; fi
  sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
  sudo -n pkill -INT -f "win-serie.d" 2>/dev/null; sleep 3; sudo -n pkill -KILL -f "win-serie.d|vncviewer" 2>/dev/null
  vf=$(awk '{s+=$NF} END{print s+0}' $R/stats.txt 2>/dev/null)
  ud=$(grep -c "#UD" $R/dtrace.txt 2>/dev/null)
  echo "corsa $k: $esito desktop=${desk}s wsl=$wslr udL2=$ud | $(grep VMfail $R/stats.txt | tr '\n' ' ')" | tee -a $S/riassunto.txt
  k=$((k+1)); sleep 10
done
sudo -n sysctl hw.vmm.vmx.diag_ud=0 >/dev/null
ls /dev/vmm 2>/dev/null || echo "/dev/vmm pulito"
echo "OUTPUT $S"
