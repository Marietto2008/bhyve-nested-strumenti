#!/bin/sh
# Claude 22/10/2026 -- B1 (parere #28), passo 8: 3 + 3 compilazioni, vept_keep 1 contro 0,
# stesso modulo, verifica HPA spenta, ordine ABBAAB. Ogni corsa: Windows da capo, build, spegnimento.
B=/mnt/linuxulator2/vm/wsl2/fbsd
n=0
for k in 1 0 0 1 1 0; do
	n=$((n+1))
	echo "######## corsa $n: vept_keep=$k  $(date +%T)"
	sh $B/run-b1win.sh $k 0 AB$n-k$k 2>&1 | grep -E "^real|kernel rc|bhyve CPU|cumulativo|spegnimento|OUTPUT|NON|USCITO"
	sleep 30
done
echo "######## FINE $(date +%T)"
