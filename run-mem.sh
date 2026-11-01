#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-mem.sh.non-conforme
echo "INERTE: run-mem.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-mem.sh.non-conforme" >&2; exit 4
O=/mnt/linuxulator2/vm/wsl2/fbsd/logs/mem-$(date +%Y%m%d-%H%M); mkdir -p $O
N=/mnt/linuxulator2/vm/wsl2/fbsd/freebsd-nested/tools/nested
D=/mnt/linuxulator2/vm/wsl2/fbsd/dtrace
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
sudo -n sysctl hw.vmm.vmx.diag_efer=0 hw.vmm.vmx.diag_ud=0 >/dev/null
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n dtrace -s $D/win-mem.d -o $O/efer.txt 2>/dev/null &
sleep 4
sudo -n sh $N/12-Windows-11-vm12-senza-gpu > $O/script.log 2>&1 &
i=0; while [ $i -lt 60 ]; do [ -e /dev/vmm/vm0:12 ] && break; sleep 1; i=$((i+1)); done
[ -e /dev/vmm/vm0:12 ] || echo "VM NON creata"; j=0; while [ $j -lt 7200 ] && pgrep -x bhyve >/dev/null; do sleep 1; j=$((j+1)); done; echo "bhyve vivo per $j s dopo la creazione"
b=$(pgrep -x bhyve); [ -n "$b" ] && { sudo -n kill -KILL $b; sleep 2; }
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n pkill -KILL -f "win-mem|vncviewer" 2>/dev/null
sudo -n sysctl hw.vmm.vmx.diag_efer=0 hw.vmm.vmx.diag_ud=0 >/dev/null
echo "=== coda:"; grep -vE "^ *[0-9]+ ms VP[0-9] slot" $O/efer.txt | tail -40
echo "OUTPUT: $O"
ls /dev/vmm 2>/dev/null || echo "/dev/vmm pulito"