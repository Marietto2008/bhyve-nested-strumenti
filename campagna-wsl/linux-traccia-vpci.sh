#!/bin/sh
# linux-traccia-vpci.sh -- Claude 03/11/2026. In Debian (WSL, kernel Linux): la sequenza di scritture di configurazione
# che Linux fa su un bus vPCI virtio di Hyper-V. Si rifa' il probe del bus di VIRTIOFS (dominio cf51, non quello della
# console hvc0) con un kprobe su _hv_pcifront_write_config (where, size, val).
T=/sys/kernel/tracing; [ -e $T/kprobe_events ] || mount -t tracefs nodev $T
# il GUID del bus cambia a ogni avvio della VM: e' quello il cui secondo campo e' il dominio PCI di virtiofs (0x105a)
for p in /sys/bus/pci/devices/*; do [ "$(cat $p/device)" = "0x105a" ] && dom=$(basename $p | cut -d: -f1); done
G=$(ls /sys/bus/vmbus/drivers/hv_pci/ | grep -i -- "-$dom-" | head -1)
echo "virtiofs: dominio $dom, bus vmbus $G"; [ -n "$G" ] || exit 1
echo 'p:claude/w _hv_pcifront_write_config where=%si:s32 size=%dx:s32 val=%cx:x32' > $T/kprobe_events
echo > $T/trace; echo 1 > $T/events/claude/w/enable; echo 1 > $T/tracing_on
echo "== unbind $(date +%T)"; echo $G > /sys/bus/vmbus/drivers/hv_pci/unbind; sleep 2
echo "== bind $(date +%T)"; echo $G > /sys/bus/vmbus/drivers/hv_pci/bind; sleep 3
echo 0 > $T/events/claude/w/enable
grep 'where=' $T/trace | sed 's/^.*where=/where=/' | head -120
echo > $T/kprobe_events
for p in /sys/bus/pci/devices/*; do [ "$(cat $p/device)" = "0x105a" ] && { echo "dopo: $p"; head -5 $p/resource; echo "comando: $(od -An -tx1 -j4 -N2 $p/config)"; }; done
dmesg | tail -12
