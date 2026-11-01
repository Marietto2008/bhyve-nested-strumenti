#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-verifica-fix.sh.non-conforme
echo "INERTE: run-verifica-fix.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-verifica-fix.sh.non-conforme" >&2; exit 4
# Verifica dei commit e8efe28 + 6496bc2 + 98c3fac (parere #15 di Astra): 9 corse.
# Atteso: zero synth_exit con 0xd1, zero slot SINT3 occupati, zero winexit
# owner=1, zero vmfail, nessun rinvio mai chiuso. Baseline: 6 stalli su 9.
O=/mnt/linuxulator2/vm/nested-work/logs/verifica-$(date +%Y%m%d-%H%M)
mkdir -p $O
SP=/tmp/claude-1001/-mnt-linuxulator2-freebsd-radxa-src/b3d0f7b6-b200-4070-a188-1436b7dd0836/scratchpad
N=/mnt/linuxulator2/vm/nested-work/freebsd-nested/tools/nested
D=/mnt/linuxulator2/vm/nested-work/dtrace
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
echo "output in $O"
for k in 1 2 3 4 5 6 7 8 9; do
  echo "######## corsa $k"
  sudo -n sysctl hw.vmm.vmx.diag_vec=209 hw.vmm.vmx.diag_slot=768 >/dev/null
  sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
  sudo -n dtrace -s $D/win-verify.d -o $O/v$k-tr.txt 2>$O/v$k-dterr.txt &
  sleep 4
  sudo -n sh $N/12-Windows-11-vm12-senza-gpu > $O/v$k-script.log 2>&1 &
  i=0; while [ $i -lt 40 ]; do pgrep -x bhyve >/dev/null && break; sleep 1; i=$((i+1)); done
  if ! pgrep -x bhyve >/dev/null; then echo "  bhyve NON partito"; else
    sudo -n python3 $SP/slotwatch3.py 0x11ff00000 256 60 > $O/v$k-slot.txt 2>&1
  fi
  b=$(pgrep -x bhyve); [ -n "$b" ] && { sudo -n kill -KILL $b; sleep 2; }
  sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
  sudo -n pkill -INT -f "win-verify" 2>/dev/null; sleep 2
  sudo -n pkill -KILL -f "win-verify|vncviewer" 2>/dev/null; sleep 1
  grep -q "SLOT OCCUPATO" $O/v$k-slot.txt && echo "  SLOT OCCUPATO (stallo)" || echo "  slot libero alla fine"
  echo "  !!! righe: $(grep -c '!!!' $O/v$k-tr.txt 2>/dev/null)"
done
sudo -n sysctl hw.vmm.vmx.diag_vec=0 >/dev/null
ls /dev/vmm 2>/dev/null || echo "/dev/vmm pulito"
