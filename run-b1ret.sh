#!/bin/sh
# Claude 22/10/2026 -- parere #29: Windows + WSL2, compilazione, con B1 e retry 0
# (baseline: foglie perse per motivo) contro retry 1, piu' una corsa con B1 spento
# per il confronto degli INVEPT per RIP. Ordine: k1r0 k1r1 k0 k1r1 k1r0.
B=/mnt/linuxulator2/vm/wsl2/linux
n=0
for c in "1 0" "1 1" "0 1" "1 1" "1 0"; do
	set -- $c; n=$((n+1))
	echo "######## corsa $n: vept_keep=$1 retries=$2  $(date +%T)"
	sh $B/run-b1win.sh $1 0 RT$n-k$1r$2 $2 2>&1 | /usr/bin/grep -E "^real|kernel rc|bhyve CPU|cumulativo|spegnimento|OUTPUT|NON|USCITO|^   "
	sleep 30
done
echo "######## FINE $(date +%T)"
