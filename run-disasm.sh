#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-disasm.sh.non-conforme
echo "INERTE: run-disasm.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-disasm.sh.non-conforme" >&2; exit 4
# Astra #17 Fase A: disassemblare l'istruzione a user-RIP 0x7ff..43xx dove smss
# prende #UD. smss resta in loop di EPT violation su quella pagina per secondi
# prima di morire: si cattura CR3+RIP a VM VIVA e si leggono i byte (gva.py).
O=/mnt/linuxulator2/vm/nested-work/logs/disasm-$(date +%Y%m%d-%H%M); mkdir -p $O
SP=/tmp/claude-1001/-mnt-linuxulator2-freebsd-radxa-src/b3d0f7b6-b200-4070-a188-1436b7dd0836/scratchpad
N=/mnt/linuxulator2/vm/nested-work/freebsd-nested/tools/nested
D=/mnt/linuxulator2/vm/nested-work/dtrace
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
# tracciatore: RIP+GPA+qual delle EPT violation, per sapere l'indirizzo esatto
sudo -n dtrace -s $D/win-udgen.d -o $O/gen.txt 2>/dev/null &
sleep 4
sudo -n sh $N/12-Windows-11-vm12-senza-gpu > $O/script.log 2>&1 &
i=0; while [ $i -lt 60 ]; do [ -e /dev/vmm/vm0:12 ] && break; sleep 1; i=$((i+1)); done
[ -e /dev/vmm/vm0:12 ] || { echo "VM NON creata"; exit 1; }
echo "VM su; cerco un vcpu bloccato su 0x7ff..43xx (polling di --get-rip)"
sudo -n bhyvectl --vm=vm0:12 --cpu=0 --get-rip > $O/rip-fmt.txt 2>&1
sudo -n bhyvectl --vm=vm0:12 --cpu=0 --get-cr3 >> $O/rip-fmt.txt 2>&1
echo "=== formato get-rip/get-cr3:"; cat $O/rip-fmt.txt
hit=""
for t in $(seq 1 200); do
  for c in 0 1; do
    rip=$(sudo -n bhyvectl --vm=vm0:12 --cpu=$c --get-rip 2>/dev/null | grep -oE '0x[0-9a-f]+' | tail -1)
    case "$rip" in
      0x7ff*4[0-9a-f][0-9a-f]|0x7ff*4[0-9a-f][0-9a-f][0-9a-f])
        cr3=$(sudo -n bhyvectl --vm=vm0:12 --cpu=$c --get-cr3 2>/dev/null | grep -oE '0x[0-9a-f]+' | tail -1)
        echo "HIT cpu=$c rip=$rip cr3=$cr3"; hit="$c $rip $cr3"; break;;
    esac
  done
  [ -n "$hit" ] && break
  sleep 0.2
done
if [ -n "$hit" ]; then
  set -- $hit; c=$1; rip=$2; cr3=$3
  base=$(printf '0x%x\n' $(( $rip - 0x20 )))
  echo "=== leggo 96 byte da $base (rip $rip, cr3 $cr3) ==="
  sudo -n python3 $SP/gva.py $cr3 $base 96 $O/code.bin | tee $O/read.txt
  # anche la pagina intera, per il contesto della funzione
  pbase=$(printf '0x%x\n' $(( $rip & ~0xfff )))
  sudo -n python3 $SP/gva.py $cr3 $pbase 4096 $O/page.bin >/dev/null 2>&1
  echo "=== RIP esatto: $rip ; offset in pagina: $(printf '0x%x' $(( $rip & 0xfff ))) ==="
else
  echo "nessun hit: il vcpu non e' stato colto su quel RIP"
fi
b=$(pgrep -x bhyve); [ -n "$b" ] && { sudo -n kill -KILL $b; sleep 2; }
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n pkill -KILL -f "win-udgen|vncviewer" 2>/dev/null
echo "OUTPUT: $O"; echo "RIP catturato: $rip"
ls /dev/vmm 2>/dev/null || echo "/dev/vmm pulito"
