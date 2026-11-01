#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-wrefer.sh.non-conforme
echo "INERTE: run-wrefer.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-wrefer.sh.non-conforme" >&2; exit 4
O=/mnt/linuxulator2/vm/wsl2/fbsd/logs/wrefer-$(date +%Y%m%d-%H%M); mkdir -p $O
N=/mnt/linuxulator2/vm/wsl2/fbsd/freebsd-nested/tools/nested
S=/tmp/claude-1001/-mnt-linuxulator2-freebsd-radxa-src/b3d0f7b6-b200-4070-a188-1436b7dd0836/scratchpad
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n dtrace -s $S/win-wrefer.d -o $O/w.txt 2>/dev/null &
sleep 4
sudo -n sh $N/12-Windows-11-vm12-senza-gpu > $O/script.log 2>&1 &
i=0; while [ $i -lt 60 ]; do [ -e /dev/vmm/vm0:12 ] && break; sleep 1; i=$((i+1)); done
[ -e /dev/vmm/vm0:12 ] && sleep 50 || echo "VM NON creata"
b=$(pgrep -x bhyve); [ -n "$b" ] && { sudo -n kill -KILL $b; sleep 2; }
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n pkill -KILL -f "win-wrefer|vncviewer" 2>/dev/null
echo "=== WRMSR EFER di L2 arrivate a vmx_wrmsr:"; grep -c "vmx_wrmsr(EFER)" $O/w.txt
grep "vmx_wrmsr(EFER)" $O/w.txt | head -4
echo "=== altri MSR a vmx_wrmsr (ultimo blocco):"; tail -20 $O/w.txt | grep "altri MSR"
echo "OUTPUT: $O"; ls /dev/vmm 2>/dev/null || echo "/dev/vmm pulito"
