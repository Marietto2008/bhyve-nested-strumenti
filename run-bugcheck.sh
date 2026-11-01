#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-bugcheck.sh.non-conforme
echo "INERTE: run-bugcheck.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-bugcheck.sh.non-conforme" >&2; exit 4
# 4 corse: parametri del bugcheck della root (win-bugcheck.d) + criteri di
# verifica (win-verify.d). Corretto il difetto del banco di prova del 19/10:
# si aspetta che la memoria della VM esista prima di misurare.
O=/mnt/linuxulator2/vm/nested-work/logs/bugcheck-$(date +%Y%m%d-%H%M)
mkdir -p $O
N=/mnt/linuxulator2/vm/nested-work/freebsd-nested/tools/nested
D=/mnt/linuxulator2/vm/nested-work/dtrace
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
echo "output in $O"
for k in 1 2 3 4; do
  echo "######## corsa $k  $(date +%H:%M:%S)"
  sudo -n sysctl hw.vmm.vmx.diag_vec=209 hw.vmm.vmx.diag_slot=768 >/dev/null
  sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
  sudo -n dtrace -s $D/win-verify.d   -o $O/b$k-verify.txt 2>/dev/null &
  sudo -n dtrace -s $D/win-bugcheck.d -o $O/b$k-bugcheck.txt 2>/dev/null &
  sleep 4
  sudo -n sh $N/12-Windows-11-vm12-senza-gpu > $O/b$k-script.log 2>&1 &
  i=0; while [ $i -lt 60 ]; do [ -e /dev/vmm/vm0:12 ] && break; sleep 1; i=$((i+1)); done
  if [ ! -e /dev/vmm/vm0:12 ]; then echo "  VM NON creata"; else
    echo "  VM su; 75 s"; sleep 75; fi
  b=$(pgrep -x bhyve); [ -n "$b" ] && { sudo -n kill -KILL $b; sleep 2; }
  sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
  sudo -n pkill -INT -f "win-verify|win-bugcheck" 2>/dev/null; sleep 2
  sudo -n pkill -KILL -f "win-verify|win-bugcheck|vncviewer" 2>/dev/null; sleep 1
  echo "  MSR di crash:"; grep "WRMSR" $O/b$k-bugcheck.txt | head -8
  echo "  ultimo tick: $(grep 'ultimo tick' $O/b$k-bugcheck.txt | tail -1)"
  echo "  !!!: $(grep -c '!!!' $O/b$k-verify.txt)"
done
sudo -n sysctl hw.vmm.vmx.diag_vec=0 >/dev/null
ls /dev/vmm 2>/dev/null || echo "/dev/vmm pulito"
