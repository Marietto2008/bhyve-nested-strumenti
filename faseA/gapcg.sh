#!/bin/bash
# Claude 23/10/2026 -- parere #35 §4: prova A1/B/A2 sul limite CFS del cgroup utente
# di WSL2, nella stessa sessione WSL, una variabile alla volta.
#  A1 = cpu.max originale, B = cpu.max "max <periodo>", A2 = di nuovo l'originale;
#  in tutte e tre lo stesso carico della prova A (I/O su ext4) e gapmon a priorita'
#  normale. cgmon, fuori dal cgroup limitato, campiona ogni 20 ms schedstat del
#  campionatore, cpu.stat (e cpu.stat.local) di tutta la catena e /proc/stat.
# Il valore originale si salva prima di toccarlo e si rimette SEMPRE (trap su EXIT).
# uso: gapcg.sh <secondi per fase> <ip host>
D="${1:-480}"; H="${2:-IP-HOST}"
L=/mnt/c/claude/faseA
exec > "$L/gapcg.log" 2>&1
cd /root || exit 1
for f in gapmon cgmon; do
	tr -d '\r' < "$L/$f.c" > "$f.c"
	gcc -O2 -pthread -o "$f" "$f.c" || { echo "$f non compila"; echo GAP-FINE; exit 1; }
done
MNT=$(findmnt -n -t cgroup2 -o TARGET | head -1)
echo "=== $(date -u +%FT%T.%N) prova A1/B/A2, $D s per fase, kernel $(uname -r), CPU $(nproc)"
echo "== cgroup2 montato su: ${MNT:-NESSUNO}"
[ -n "$MNT" ] || { echo "niente cgroup v2"; echo GAP-FINE; exit 1; }

SAVED=/root/gapcg-cpumax.salvato
: > "$SAVED"
ripristina() {	# rimette ogni cpu.max salvato
	local d v
	while IFS='|' read -r d v; do
		[ -n "$d" ] || continue
		printf '%s\n' "$v" > "$d/cpu.max" &&
		    echo "ripristinato $d/cpu.max = $(cat "$d/cpu.max")" ||
		    echo "!!! RIPRISTINO FALLITO $d/cpu.max (voleva $v)"
	done < "$SAVED"
	: > "$SAVED"
}
trap ripristina EXIT
trap 'exit 1' INT TERM HUP

catena() {	# catena <pid>: le directory cgroup dal gruppo del processo alla radice
	local p d
	p=$(sed -n 's/^0:://p' "/proc/$1/cgroup")
	d="$MNT$p"
	while [ "$d" != "$MNT" ] && [ -n "$d" ]; do
		echo "$d"
		d=$(dirname "$d")
	done
}
mostra() {	# mostra <etichetta> <dir...>: cpu.max e cpu.stat di ogni gruppo
	local t="$1" d
	shift
	for d in "$@"; do
		echo "  [$t] $d cpu.max=$(cat "$d/cpu.max" 2>/dev/null || echo assente)"
		echo "        cpu.stat: $(tr '\n' ' ' < "$d/cpu.stat" 2>/dev/null)"
		[ -f "$d/cpu.stat.local" ] && echo "        cpu.stat.local: $(tr '\n' ' ' < "$d/cpu.stat.local")"
	done
}
io_ciclo() {	# come gapdiag.sh, prova A: 8 x 128 MB, sha256, drop_caches, riverifica
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

for F in A1 B A2; do
	echo "######## fase $F $(date -u +%T)"
	./gapmon "$D" "$H" 7123 > "/root/gapmon-$F.txt" &
	GP=$!
	sleep 1
	mapfile -t CG < <(catena "$GP")
	echo "== gapmon pid $GP, /proc/$GP/cgroup: $(tr '\n' ' ' < "/proc/$GP/cgroup")"
	echo "== schedstat iniziale: $(cat "/proc/$GP/task/$GP/schedstat")"
	mostra "$F inizio" "${CG[@]}"
	if [ "$F" = B ]; then
		for d in "${CG[@]}"; do
			[ -f "$d/cpu.max" ] || continue
			v=$(cat "$d/cpu.max")
			[ "${v%% *}" = max ] && continue
			printf '%s|%s\n' "$d" "$v" >> "$SAVED"
			printf 'max %s\n' "${v##* }" > "$d/cpu.max" &&
			    echo "  B: $d/cpu.max da '$v' a '$(cat "$d/cpu.max")'" ||
			    echo "  !!! B: scrittura di $d/cpu.max FALLITA"
		done
		[ -s "$SAVED" ] || echo "  B: nessun gruppo con limite nella catena"
	fi
	# l'osservatore nel cgroup radice, fuori dal limite
	( echo "$BASHPID" > "$MNT/cgroup.procs" 2>/dev/null || echo "  cgmon NON spostato nella radice"
	  exec ./cgmon "$((D - 2))" "$GP" "/root/cgmon-$F.txt" "${CG[@]}" ) &
	CM=$!
	sleep 1
	echo "== cgmon pid $CM, cgroup: $(tr '\n' ' ' < "/proc/$CM/cgroup" 2>/dev/null)"
	t0=$(date +%s)
	while [ $(( $(date +%s) - t0 )) -lt $((D - 60)) ]; do io_ciclo /root/gapio; done
	wait "$GP" "$CM"
	mostra "$F fine" "${CG[@]}"
	[ "$F" = B ] && ripristina
	cat "/root/gapmon-$F.txt" > "$L/gapcg-gapmon-$F.txt"
	cat "/root/cgmon-$F.txt" > "$L/gapcg-cgmon-$F.txt"
	echo "fase $F: buchi $(grep -c '^BUCO' "/root/gapmon-$F.txt")"
	sleep 30
done
echo "=== $(date -u +%FT%T.%N) fine"
echo GAP-FINE
