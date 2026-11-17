#!/bin/sh
# avvio-rete.sh <etichetta> -- Claude 10/11/2026, diagnosi Fable 020 (rete di Windows con MSI-X mai programmata).
# UN avvio misurato della vm0:13 in configurazione A (vm0-13-qemu.sh --qemu-sipi --audio, QEMU 85e77202b1 con le
# tracce msix_table_write/msix_reset/pci_cfg_write/pci_update_mappings e -d invalid_mem):
#   1. contatori vept/nested PRIMA; 2. sonda msix-vept.d accesa PRIMA della VM (solo vmx_vept_fault filtrato);
#   3. avvio con VNC minimizzata; 4. attesa: rete OK (virtio-net smascherata nella traccia + ssh) o GUASTO
#      (>=300 notifiche mascherate di virtio-net), al massimo 10 min; 5. sonda fermata, contatori DOPO, riepilogo.
# NON spegne Windows: lo decide chi lo lancia (rete OK -> shutdown /s via ssh; guasto -> SIGTERM a QEMU).
# Esiti in ../dati-bhyve/avvio-rete-<ora>-<etichetta>/.
set -u
ET=${1:-senza-etichetta}
# SONDA=0: niente DTrace (10/11: i 3 avvii buoni avevano la sonda, i 2 guasti no; le sonde cambiano i tempi)
SONDA=${SONDA:-1}
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
W=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl
LOGS=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs
P=/home/marietto/.config/claude-wsl2/password-windows
T=$(date +%Y%m%d-%H%M%S); O=$D/dati-bhyve/avvio-rete-$T-$ET
mkdir -p "$O" || exit 4
R=$O/riepilogo.txt
dica() { echo "$(date +%T) $*" | tee -a "$R"; }
contatori() { sysctl hw.vmm.vmx | grep -E 'vept_scan_retry|vept_memgen|vept_keep_(full|scan)|nested_ept_mmio_emulated|nested_ept02_faults_l0|nested_ept12_viol_reflected|nested_l2_entries|apicacc'; }

pgrep -q qemu-system && { echo "STOP: un QEMU e' gia' vivo"; exit 4; }
dica "avvio $T etichetta=$ET sonda=$SONDA modulo=$(kldstat -v | grep -o 'vmm-restore.ko ([^)]*)' | head -1) sha=$(sha256 -q /boot/kernel/vmm-restore.ko | cut -c1-8)"
contatori > "$O/contatori-prima.txt"
if [ "$SONDA" = 1 ]; then sudo -n daemon -o "$O/msix-vept.txt" dtrace -qs $D/strumenti/msix-vept.d; else : > "$O/msix-vept.txt"; fi
sleep 3
AV=$LOGS/vm0-13-avvio-$T.txt
sudo -n daemon -o "$AV" sh $W/vm0-13-qemu.sh --qemu-sipi --audio
i=0; until nc -z -w 1 127.0.0.1 5913 2>/dev/null; do i=$((i + 1)); [ $i -gt 40 ] && { dica "VNC non risponde"; break; }; sleep 1; done
export DISPLAY=${DISPLAY:-:0} XAUTHORITY=${XAUTHORITY:-/home/marietto/.Xauthority}
pgrep -f 'vncviewer 127.0.0.1:5913' >/dev/null || daemon -f vncviewer 127.0.0.1:5913
sleep 4; for w in $(xdotool search --name vm0-13 2>/dev/null); do xdotool windowminimize $w; done
TR=$(sudo -n sed -n 's/^traccia virtio: //p' "$AV" | head -1)
dica "registro $AV, traccia $TR"

esito=TEMPO; t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 600 ]; do
	sleep 10
	if sudo -n grep -q 'virtio-net-pci vector 0 maschera 1->0' "$TR"; then esito=OK; break; fi
	nm=$(sudo -n grep -c 'msix_notify_masked dev virtio-net' "$TR")
	[ "$nm" -ge 300 ] && { esito=GUASTO; break; }
done
dica "esito rete: $esito dopo $(( $(date +%s) - t0 )) s"
# tre minuti in piu': Windows riprogramma le tabelle anche dopo (driver che ripartono)
sleep 180
p=$(pgrep -f "dtrace -qs $D/strumenti/msix-vept.d"); [ -n "$p" ] && sudo -n kill -INT $p
sleep 2
contatori > "$O/contatori-dopo.txt"
sudo -n grep -E 'msix_|pci_cfg_write|pci_update_mappings|Invalid' "$TR" | grep -v -E 'msix_notify_(send|masked)' > "$O/traccia-pci-msix.txt"
{
	echo "--- traccia QEMU (eventi PCI/MSI-X, senza notifiche): $(wc -l < "$O/traccia-pci-msix.txt") righe"
	for d in virtio-net-pci qemu-xhci; do
		echo "$d: scritture tabella=$(grep -c "msix_table_write dev $d" "$O/traccia-pci-msix.txt") reset=$(grep -c "msix_reset dev $d" "$O/traccia-pci-msix.txt") accensioni=$(grep -c "msix_write_config dev $d enabled 1" "$O/traccia-pci-msix.txt") smascheramenti=$(grep -c "msix_mask_update dev $d vector [0-9]* maschera 1->0" "$O/traccia-pci-msix.txt")"
	done
	echo "accessi MMIO rifiutati (invalid_mem): $(grep -c Invalid "$O/traccia-pci-msix.txt")"
	echo "notifiche mascherate virtio-net: $(sudo -n grep -c 'msix_notify_masked dev virtio-net' "$TR")"
	echo "--- sonda L0 (vmx_vept_fault sulle due pagine):"
	sudo -n cat "$O/msix-vept.txt" > "$O/msix-vept-copia.txt"	# il file della sonda e' di root
	for e in OK-FOGLIA-INSTALLATA MMIO VIOL MISCONF; do
		echo "  $e: virtio-net $(grep " $e " "$O/msix-vept-copia.txt" | grep -c 'gpa=0x81046') xhci $(grep " $e " "$O/msix-vept-copia.txt" | grep -c 'gpa=0x10000070')"
	done
	echo "  memgen: $(grep -c ' memgen ' "$O/msix-vept-copia.txt")"
	echo "--- contatori (prima -> dopo):"
	paste -d' ' "$O/contatori-prima.txt" "$O/contatori-dopo.txt" | awk '{print "  " $1, $2, "->", $4}'
} | tee -a "$R"
dica "fine; QEMU $(pgrep -q qemu-system && echo vivo || echo uscito)"
