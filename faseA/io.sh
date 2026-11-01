#!/bin/bash
# Claude 20/10/2026 fase A (parere #23): integrita' I/O. Per ogni ciclo: 8 file da
# 128 MB casuali su ext4 (/root/io) e copia su NTFS (/mnt/c/claude/io), sha256,
# sync, drop_caches, riverifica. uso: io.sh <cicli>
N="${1:-5}"
err=0
mkdir -p /root/io /mnt/c/claude/io
for c in $(seq "$N"); do
	t0=$(date +%s)
	for i in $(seq 8); do
		dd if=/dev/urandom of="/root/io/f$i" bs=1M count=128 status=none
	done
	(cd /root/io && sha256sum f* > /root/io.sha)
	cp /root/io/f1 /root/io/f2 /root/io/f3 /root/io/f4 /root/io/f5 \
	    /root/io/f6 /root/io/f7 /root/io/f8 /mnt/c/claude/io/
	sync
	echo 3 > /proc/sys/vm/drop_caches
	if ! (cd /root/io && sha256sum -c --quiet /root/io.sha); then
		echo "!!! ciclo $c: ERRORE ext4"; err=$((err + 1))
	fi
	if ! (cd /mnt/c/claude/io && sha256sum -c --quiet /root/io.sha); then
		echo "!!! ciclo $c: ERRORE NTFS"; err=$((err + 1))
	fi
	echo "io ciclo $c errori_cumulati=$err durata=$(( $(date +%s) - t0 ))s"
done
echo "IO-FINE errori=$err"
