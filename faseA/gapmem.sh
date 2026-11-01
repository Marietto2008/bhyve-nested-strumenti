#!/bin/bash
# Claude 24/10/2026 -- parere #42 §3: UNA fase della prova A/B/A su autoMemoryReclaim, in UNA
# sessione WSL (fra le fasi l'host fa wsl --shutdown e cambia .wslconfig). Stesso carico della
# prova ext4 di gapcg.sh (8 x 128 MB, sha256, sync, drop_caches, rilettura), con:
#  - verifiche preliminari del parere (uname, page_reporting_order, messaggi di hv_balloon e del
#    free page reporting, meminfo, vmstat) e dmesg intero, prima e dopo;
#  - W cicli di RISCALDAMENTO, esclusi dalle statistiche, poi gapmon per D s;
#  - un marcatore con l'ora di Linux (CLOCK_REALTIME, come gapmon e memmon) a ogni passo
#    del ciclo: dd, sha, sync, drop, rilettura, ok;
#  - memmon: MemFree/Cached/... e contatori di vmstat ogni 100 ms, per tutta la fase.
# Nessuna scrittura in /sys o /proc oltre al drop_caches del carico stesso.
# uso: gapmem.sh <secondi> <ip host> <fase A1|B|A2> <cicli di riscaldamento>
D="${1:-480}"; H="${2:-IP-HOST}"; F="${3:-X}"; W="${4:-3}"
L=/mnt/c/claude/faseA
exec > "$L/gapmem-$F.log" 2>&1
cd /root || exit 1
for f in gapmon memmon; do
	tr -d '\r' < "$L/$f.c" > "$f.c"
	gcc -O2 -pthread -o "$f" "$f.c" || { echo "$f non compila"; echo GAP-FINE; exit 1; }
done
mk() { echo "CICLO $1 $2 $(date +%s.%N)"; }
istantanea() {	# istantanea <file>: le verifiche del parere #42 §3, e qualcosa in piu'
	{
		echo "== $(date -u +%FT%T.%N) fase $F"
		echo "== uname -r"; uname -r
		echo "== page_reporting_order"; cat /sys/module/page_reporting/parameters/page_reporting_order 2>&1
		echo "== dmesg (free page reporting, cold memory discard, hv_balloon)"
		dmesg | grep -Ei 'Free page reporting|Cold memory discard|hv_balloon'
		echo "== meminfo"; grep -E 'MemTotal|MemFree|MemAvailable|Cached|Buffers' /proc/meminfo
		echo "== vmstat"; grep -E 'pgfree|pgalloc|pgscan|pgsteal' /proc/vmstat
		echo "== parametri di hv_balloon"; grep -H . /sys/module/hv_balloon/parameters/* 2>&1
		echo "== debugfs hv-balloon"; cat /sys/kernel/debug/hv-balloon 2>&1
		echo "== cmdline"; cat /proc/cmdline
		echo "== free -m"; free -m
	} > "$1" 2>&1
}
io_ciclo() {	# io_ciclo <dir> <etichetta>
	local d="$1" n="$2"
	[ -n "$d" ] || return 1
	mkdir -p "$d"
	mk "$n" dd
	for i in 1 2 3 4 5 6 7 8; do dd if=/dev/urandom of="$d/f$i" bs=1M count=128 status=none; done
	mk "$n" sha
	(cd "$d" && sha256sum f* > /root/gap.sha)
	mk "$n" sync
	sync
	mk "$n" drop
	echo 3 > /proc/sys/vm/drop_caches
	mk "$n" rilettura
	if (cd "$d" && sha256sum -c --quiet /root/gap.sha); then
		mk "$n" ok
	else
		mk "$n" ERRORE; echo "!!! io ERRORE"
	fi
}
echo "=== $(date -u +%FT%T.%N) fase $F, $D s, riscaldamento $W cicli, kernel $(uname -r), CPU $(nproc)"
istantanea "$L/gapmem-pre-$F.txt"
dmesg > "$L/gapmem-dmesg-pre-$F.txt" 2>&1
./memmon 100000 "/root/memmon-$F.txt" &
MM=$!
echo "RISCALDAMENTO-INIZIO $(date +%s.%N)"
for n in $(seq 1 "$W"); do io_ciclo /root/gapio "R$n"; done
echo "RISCALDAMENTO-FINE $(date +%s.%N)"
./gapmon "$D" "$H" 7123 > "/root/gapmon-$F.txt" &
GP=$!
t0=$(date +%s); n=0
while [ $(( $(date +%s) - t0 )) -lt $((D - 60)) ]; do n=$((n + 1)); io_ciclo /root/gapio "$n"; done
wait "$GP"
echo "PROVA-FINE $(date +%s.%N)"
kill "$MM"; wait "$MM" 2>/dev/null
istantanea "$L/gapmem-post-$F.txt"
dmesg > "$L/gapmem-dmesg-post-$F.txt" 2>&1
cat "/root/gapmon-$F.txt" > "$L/gapmem-gapmon-$F.txt"
cat "/root/memmon-$F.txt" > "$L/gapmem-memmon-$F.txt"
echo "fase $F: buchi $(grep -c '^BUCO' "/root/gapmon-$F.txt")"
echo GAP-FINE
