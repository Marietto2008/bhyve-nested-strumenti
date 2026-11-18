#!/bin/sh
# aggancia-dopo-login.sh <log dtrace>: aspetta che la console di WSL in Windows
# mostri il login di FreeBSD, poi avvia la traccia delle iniezioni #PF (cosi'
# le sonde non rallentano l'avvio oltre il timeout di CreateVm).
L=$1; P=/home/marietto/.config/claude-wsl2/password-windows
sleep 30
# prima: la prova nuova deve aver lanciato wsl.exe (il suo registro e la console
# vecchia vengono cancellati all'inizio), poi il login nella console NUOVA
t0=$(date +%s)
until timeout 30 sshpass -f $P ssh -o ConnectTimeout=20 marietto@IP-WINDOWS-B 'findstr /c:"comando: wsl.exe" C:\claude\prova-wsl-fbsd.log' 2>/dev/null | grep -q comando; do
	[ $(( $(date +%s) - t0 )) -gt 600 ] && { echo "wsl.exe non lanciato in 10 minuti"; exit 1; }
	sleep 10
done
date +"%T wsl.exe lanciato, aspetto il login"
sleep 20
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 600 ]; do
	if timeout 30 sshpass -f $P ssh -o ConnectTimeout=20 marietto@IP-WINDOWS-B 'findstr /c:"login:" C:\claude\wsl-fbsd\console-wsl.txt' 2>/dev/null | grep -q login; then
		date +"%T login visto, aggancio la traccia"
		sudo -n daemon -o $L dtrace -qs /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/iniezione-pf-campi.d
		exit 0
	fi
	sleep 10
done
echo "login non visto in 10 minuti"
exit 1
