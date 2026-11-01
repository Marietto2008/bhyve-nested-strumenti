#!/bin/sh
# Claude 23/10/2026 -- parere #33 §2: ABBA retry 1 / retry 2 a 4 VP veri (1x4 core),
# make -j4, verifica HPA spenta; poi una corsa a 2 VP con lo stesso -j4 per R1/R2 (§4).
B=/mnt/linuxulator2/vm/wsl2/fbsd
G=/usr/bin/grep
F="topologia|vcpu [0-3]|^real|kernel rc|bhyve CPU|cumulativo|spegnimento|OUTPUT|NON|USCITO|^   "
for c in "1 A1" "2 B1" "2 B2" "1 A2"; do
	set -- $c
	echo "######## $2: 4 VP, -j4, vept_scan_retries=$1 $(date +%T)"
	VMS=12-Windows-11-vm12-senza-gpu-4core KBS=kbuild4.sh sh $B/run-b1win.sh 1 0 RT4-$2-r$1 $1 2>&1 | $G -E "$F"
	sleep 30
done
echo "######## R2VP: 2 VP, -j4, retry 1 $(date +%T)"
KBS=kbuild4.sh sh $B/run-b1win.sh 1 0 RT4-2VP-r1 1 2>&1 | $G -E "$F"
echo "######## FINE $(date +%T)"
