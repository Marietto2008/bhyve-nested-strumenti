echo ==== virtio
pciconf -lv | grep -A3 1af4
echo ==== capability e BAR
for d in $(pciconf -l | grep 1af4 | cut -d@ -f1); do echo == $d; pciconf -lbc $d; done
echo ==== memoria alta
devinfo -u | grep -i -e virtio -e pcib
