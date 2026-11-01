#!/bin/sh
# Claude 23/10/2026 -- parere #32: fase B con 4 vCPU VERI (1 socket x 4 core).
# Regressione breve (compilazione -j2 e -j4, 6 avvii), poi sessione lunga con 4 worker.
B=/mnt/linuxulator2/vm/wsl2/fbsd
G=/usr/bin/grep
VM4=12-Windows-11-vm12-senza-gpu-4core
for c in "kbuild.sh C4-j2" "kbuild4.sh C4-j4"; do
	set -- $c
	echo "######## Windows 1x4 core, $1 $(date +%T)"
	VMS=$VM4 KBS=$1 sh $B/run-b1win.sh 1 1 $2 1 2>&1 | $G -E "topologia|vCPU|vcpu|^real|kernel rc|bhyve CPU|cumulativo|spegnimento|OUTPUT|NON|USCITO|^   "
	sleep 30
done
echo "######## 6 avvii 1x4 core $(date +%T)"
VMS=$VM4 sh $B/run-serie-b1.sh 6 2>&1 | tail -10
sleep 30
echo "######## sessione lunga 1x4 core $(date +%T)"
VMS=$VM4 LOADSH=load4.sh sh $B/run-lungo-b1.sh 2>&1
echo "######## FINE $(date +%T)"
