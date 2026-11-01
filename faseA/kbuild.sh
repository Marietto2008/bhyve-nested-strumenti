#!/bin/bash
# Claude 20/10/2026 fase A (parere #23): compilazione del kernel Linux 6.6.58
# (defconfig, -j2) in Debian/WSL2, con clockmon in parallelo. Il primo tentativo
# in load.sh e' fallito subito: /usr/bin/time non c'e' (qui si usa il time di bash).
L=/mnt/c/claude/faseA
exec > "$L/kbuild.log" 2>&1
cd /root || exit 1
./clockmon 14400 > "$L/clockmon-kbuild.log" 2>&1 &
CM=$!
cd linux-6.6.58 || exit 1
make mrproper > /dev/null
make defconfig > /dev/null
# stesso stato delle cache a ogni prova (parere #24: prove A/B confrontabili)
sync
echo 3 > /proc/sys/vm/drop_caches
echo "=== $(date -u) make -j2"
time make -j2 > /root/kbuild-out.log 2>&1
echo "kernel rc=$?"
tail -5 /root/kbuild-out.log
grep -ciE "error|segmentation|internal compiler" /root/kbuild-out.log
ls -l arch/x86/boot/bzImage vmlinux
echo "=== $(date -u) fine"
[ -n "$CM" ] && kill "$CM"
wait "$CM"
echo KBUILD-FINE
