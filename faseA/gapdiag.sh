#!/bin/bash
# Claude 23/10/2026 -- parere #33 §3: una prova del filone DrvFs/9P dentro WSL2.
# uso: gapdiag.sh <A|B|C> <secondi> <ip host>
#  A = I/O su ext4 (/root), B = I/O su /mnt/c (DrvFs), C = nessun I/O da Linux
#  (in C l'I/O NTFS lo fa Windows con iogen.ps1). In tutte: gapmon (buchi, stato
#  del thread, schedstat, PSI, SYNC con l'host) e, se c'e' tracefs, sched_switch e
#  sched_wakeup del solo campionatore, con trace_clock=mono.
M="$1"; D="${2:-480}"; H="${3:-IP-HOST}"
L=/mnt/c/claude/faseA
exec > "$L/gap-$M.log" 2>&1
cd /root || exit 1
tr -d '\r' < "$L/gapmon.c" > gapmon.c
gcc -O2 -pthread -o gapmon gapmon.c || { echo "gapmon non compila"; echo GAP-FINE; exit 1; }
echo "=== $(date -u +%FT%T.%N) prova $M, $D s"
echo "== /mnt/c"; findmnt -T /mnt/c -o TARGET,FSTYPE,SOURCE,OPTIONS
echo "== kernel $(uname -r), CPU $(nproc)"
./gapmon "$D" "$H" 7123 > "/root/gapmon-$M.txt" &
GP=$!
sleep 1
T=/sys/kernel/tracing
TR=0
[ -d "$T/events" ] || mount -t tracefs nodev "$T" 2>/dev/null
if [ "$T" = /sys/kernel/tracing ] && [ -w "$T/trace_clock" ] && [ -d "$T/events/sched/sched_switch" ]; then
	TR=1
	echo 0 > "$T/tracing_on"
	echo > "$T/trace"
	echo mono > "$T/trace_clock"
	echo 8192 > "$T/buffer_size_kb"
	echo "prev_pid == $GP || next_pid == $GP" > "$T/events/sched/sched_switch/filter"
	echo "pid == $GP" > "$T/events/sched/sched_wakeup/filter"
	echo 1 > "$T/events/sched/sched_switch/enable"
	echo 1 > "$T/events/sched/sched_wakeup/enable"
	echo 1 > "$T/tracing_on"
	echo "== tracefs: sched_switch/sched_wakeup su tid $GP"
	echo "   filtro switch: $(cat "$T/events/sched/sched_switch/filter")"
	echo "   filtro wakeup: $(cat "$T/events/sched/sched_wakeup/filter")"
	echo "   enable $(cat "$T/events/sched/sched_switch/enable")/$(cat "$T/events/sched/sched_wakeup/enable") tracing_on $(cat "$T/tracing_on") clock $(cat "$T/trace_clock")"
	sleep 2
	n=$(grep -vc '^#' "$T/trace")
	echo "   eventi dopo 2 s: $n"
	if [ "$n" -eq 0 ]; then
		# ripiego: niente filtri sui campi, si filtra per processo
		echo 0 > "$T/events/sched/sched_switch/filter"
		echo 0 > "$T/events/sched/sched_wakeup/filter"
		echo "$GP" > "$T/set_event_pid"
		sleep 2
		echo "   ripiego set_event_pid=$(cat "$T/set_event_pid"): eventi dopo 2 s $(grep -vc '^#' "$T/trace")"
	fi
else
	echo "== tracefs NON disponibile"
fi
io_ciclo() {	# io_ciclo <dir>: 8 x 128 MB, sha256, drop_caches, riverifica
	local d="$1"
	[ -n "$d" ] || return 1
	mkdir -p "$d"
	for i in 1 2 3 4 5 6 7 8; do dd if=/dev/urandom of="$d/f$i" bs=1M count=128 status=none; done
	(cd "$d" && sha256sum f* > /root/gap.sha); sync; echo 3 > /proc/sys/vm/drop_caches
	if (cd "$d" && sha256sum -c --quiet /root/gap.sha); then
		echo "io ok $(date -u +%T)"
	else
		echo "!!! io ERRORE $(date -u +%T)"
	fi
}
t0=$(date +%s)
case "$M" in
A) while [ $(( $(date +%s) - t0 )) -lt $((D - 60)) ]; do io_ciclo /root/gapio; done ;;
B) while [ $(( $(date +%s) - t0 )) -lt $((D - 60)) ]; do io_ciclo /mnt/c/claude/gapio; done ;;
C) sleep $((D - 30)) ;;
esac
wait "$GP"
if [ "$TR" = 1 ]; then
	echo 0 > "$T/tracing_on"
	echo 0 > "$T/events/sched/sched_switch/enable"
	echo 0 > "$T/events/sched/sched_wakeup/enable"
	cat "$T/trace" > "$L/gap-$M-trace.txt"
fi
cat "/root/gapmon-$M.txt" > "$L/gapmon-$M.txt"
echo "=== $(date -u +%FT%T.%N) fine"
grep -c "^BUCO" "/root/gapmon-$M.txt"
echo GAP-FINE
