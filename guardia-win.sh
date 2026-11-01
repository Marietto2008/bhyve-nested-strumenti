#!/bin/sh
# Claude 24/10/2026 -- parere #40 §9: la guardia WSL in Windows (C:\claude\wsl-guardia.ps1)
# deve restare ferma durante le misure.
#  guardia-win.sh aggiorna            copia la versione corrente e la riavvia
#  guardia-win.sh pausa-dopo FILE PAT  in sottofondo: aspetta che il file di Windows FILE
#                                      (in C:/claude/faseA) contenga PAT, cioe' che il
#                                      carico sia partito, poi crea C:\claude\guardia-pausa
#  guardia-win.sh riprendi             toglie la pausa
C=/mnt/linuxulator2/vm/wsl2/fbsd/faseA
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000\r' | iconv -f CP850 -t UTF-8 2>/dev/null; }
cpw() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$@"; }
case "$1" in
aggiorna)
	cpw "$C/wsl-guardia.ps1" marietto@win11:'C:/claude/wsl-guardia.ps1'
	cpw "$C/wsl-guardia.vbs" marietto@win11:'C:/claude/wsl-guardia.vbs'
	w "del C:\\claude\\guardia-pausa 2>nul & schtasks /create /tn claude-wsl-guardia /tr \"wscript.exe C:\\claude\\wsl-guardia.vbs\" /sc onlogon /ru marietto /it /f >nul & schtasks /end /tn claude-wsl-guardia >nul & schtasks /run /tn claude-wsl-guardia"
	;;
pausa-dopo)
	F="$2"; P="$3"
	T=$(mktemp -t guardia); T0=$(mktemp -t guardia0)
	# il file di una corsa precedente puo' esserci ancora: vale solo un contenuto NUOVO
	cpw marietto@win11:"C:/claude/faseA/$F" "$T0" 2>/dev/null
	k=0
	until cpw marietto@win11:"C:/claude/faseA/$F" "$T" 2>/dev/null && /usr/bin/grep -q "$P" "$T" && ! cmp -s "$T" "$T0"; do
		sleep 10; k=$((k + 1)); [ $k -gt 360 ] && { echo "guardia: carico non confermato, nessuna pausa"; exit 1; }
	done
	w "echo pausa > C:\\claude\\guardia-pausa" > /dev/null
	echo "guardia in pausa dalle $(date +%T) ($F contiene '$P')"
	: >| "$T"; : >| "$T0"
	;;
riprendi)
	w "del C:\\claude\\guardia-pausa 2>nul" > /dev/null
	echo "guardia ripresa alle $(date +%T)"
	;;
esac
