#!/bin/bash
# Claude 23/10/2026: load.sh con 4 worker e make -j4 (parere #32, 4 vCPU veri).
# Claude 20/10/2026 fase A (parere #23): carico in Debian/WSL2, tutto in una sessione.
# 1 stress-ng cpu+vm 30 min; 2 compilazione del kernel Linux (defconfig, -j2);
# 3 integrita' I/O; clockmon in parallelo per tutta la durata.
L=/mnt/c/claude/faseA
exec > "$L/load.log" 2>&1
cd /root || exit 1
tr -d '\r' < "$L/clockmon.c" > clockmon.c
tr -d '\r' < "$L/io.sh" > io.sh
gcc -O2 -o clockmon clockmon.c || exit 1
./clockmon 14400 > "$L/clockmon.log" 2>&1 &
CM=$!
echo "=== $(date -u) stress-ng"
stress-ng --cpu 4 --vm 4 --vm-bytes 512M --verify --timeout 30m --metrics-brief
echo "stress-ng rc=$?"
echo "=== $(date -u) kernel"
if [ ! -d linux-6.6.58 ]; then
	wget -q https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.58.tar.xz &&
	    tar xf linux-6.6.58.tar.xz
fi
if cd linux-6.6.58; then
	make mrproper > /dev/null
	make defconfig > /dev/null
	sync; echo 3 > /proc/sys/vm/drop_caches
	# Claude 22/10/2026: niente /usr/bin/time in Debian, time di bash
	time make -j4 > /root/kbuild.log 2>&1
	echo "kernel rc=$?"
	tail -25 /root/kbuild.log
	ls -l arch/x86/boot/bzImage
	cd /root || exit 1
fi
echo "=== $(date -u) io"
bash io.sh 5
echo "=== $(date -u) fine"
[ -n "$CM" ] && kill "$CM"
wait "$CM"
echo "clockmon rc=$?"
echo LOAD-FINE
