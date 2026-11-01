#!/bin/bash
# Claude 24/10/2026 -- parere #38 (buchi) §6: carico CPU verificato in WSL per la
# calibrazione: due "yes" per 60 s, ciascuno con ora di inizio e fine, codice d'uscita
# (timeout -> 124) e tempo CPU (time di bash: real/user/sys).
L=/mnt/c/claude/faseA/yes.log
exec >> "$L" 2>&1
echo "INIZIO $(date +%s.%N) cpu=$(nproc)"
for i in 1 2; do
	(
		s=$(date +%s.%N)
		{ time timeout 60 yes > /dev/null; } 2> "/tmp/yes$i.t"
		rc=$?
		e=$(date +%s.%N)
		echo "yes$i inizio $s fine $e rc $rc $(tr '\n' ' ' < "/tmp/yes$i.t")"
	) &
done
wait
echo "FINE $(date +%s.%N)"
