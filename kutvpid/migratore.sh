#!/bin/sh
# Claude 25/10/2026 -- parere #48 §6 e §10 passo 04: migrazione FORZATA del vCPU dei kvm-unit-tests.
# Aspetta il QEMU dei test, trova i suoi thread e li sposta alternando fra le CPU $A e $B ogni
# $P secondi (cpuset -t sposta il thread subito). Continua finche' esistono QEMU dei test; scrive
# in $OUT quanti spostamenti ha fatto per ogni processo QEMU.
# uso: migratore.sh <cpuA> <cpuB> <periodo_s> <file_out>
A=$1; B=$2; P=$3; OUT=$4
: > "$OUT"
vuoti=0
while [ $vuoti -lt 600 ]; do
	# solo il QEMU dei kvm-unit-tests (non il processo timeout che lo lancia, ne' altri QEMU)
	pid=""
	for q in $(pgrep -x qemu-system-x86_64); do
		ps -o args= -p "$q" | /usr/bin/grep -q "kut/.*\.flat" && { pid=$q; break; }
	done
	if [ -z "$pid" ]; then vuoti=$((vuoti + 1)); sleep 0.1; continue; fi
	vuoti=0; n=0; c=$A
	while kill -0 "$pid" 2>/dev/null; do
		for t in $(procstat -t "$pid" 2>/dev/null | awk 'NR>1 {print $2}'); do
			cpuset -l "$c" -t "$t" 2>/dev/null
		done
		n=$((n + 1)); [ "$c" = "$A" ] && c=$B || c=$A
		sleep "$P"
	done
	echo "pid $pid spostamenti $n" >> "$OUT"
done
