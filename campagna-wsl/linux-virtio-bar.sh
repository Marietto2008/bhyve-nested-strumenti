#!/bin/sh
# linux-virtio-bar.sh -- Claude 03/11/2026. Dentro Debian (WSL, kernel Linux): i dispositivi virtio sul vPCI di Hyper-V.
for d in /sys/bus/pci/devices/*; do
	v=$(cat "$d/vendor"); [ "$v" = "0x1af4" ] || continue
	drv=$(basename "$(readlink "$d/driver")" 2>/dev/null)
	echo "== $d dev=$(cat "$d/device") class=$(cat "$d/class") driver=$drv"
	head -6 "$d/resource"
	echo "comando PCI: $(od -An -tx1 -j4 -N2 "$d/config")"
done
dmesg | grep -iE 'hv_pci|virtio|hvc' | head -25
