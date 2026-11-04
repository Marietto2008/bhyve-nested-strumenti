for d in /sys/bus/pci/devices/*; do v=$(cat $d/vendor); i=$(cat $d/device); echo == $d $v $i class=$(cat $d/class) driver=$(basename $(readlink $d/driver) 2>/dev/null); done
for d in /sys/bus/pci/devices/*; do if [ $(cat $d/device) = 0x105a ]; then echo; echo === virtio-fs $d; echo resource:; cat $d/resource | head -6; echo config:; od -A x -t x1 $d/config | head -20; fi; done
grep -i -E 'virtio|wslg|shared' /proc/mounts
dmesg 2>/dev/null | grep -i -E 'virtio.?fs|dax|shm|105a|BAR' | head -20
