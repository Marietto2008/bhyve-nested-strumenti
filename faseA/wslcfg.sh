#!/bin/sh
# Claude 21/10/2026: prova .wslconfig (parere #26 §9), una variabile sola.
# uso: wslcfg.sh <etichetta> orig|noreclaim
#   orig      = nessun .wslconfig (configurazione originale)
#   noreclaim = [experimental] autoMemoryReclaim=disabled
# Poi wsl --shutdown, traccia per minuto (win-wslcfg.d), memoria di vmmemWSL,
# compilazione del kernel (kb-ab.sh). Log in logs/wslcfg-<etichetta>-*.
E="${1:?etichetta}"; M="${2:?orig|noreclaim}"
B=/mnt/linuxulator2/vm/wsl2/linux
C="$B/faseA"
O="$B/logs/wslcfg-$E-$(date +%Y%m%d-%H%M)"
mkdir -p "$O"
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
case "$M" in
orig)
	w "if exist %UserProfile%\\.wslconfig del %UserProfile%\\.wslconfig" ;;
noreclaim)
	w "powershell -NoProfile -Command \"Set-Content -Encoding ascii -Path \$env:UserProfile\\.wslconfig -Value '[experimental]','autoMemoryReclaim=disabled'\"" ;;
*)
	echo "modo sconosciuto: $M"; exit 1 ;;
esac
w "if exist %UserProfile%\\.wslconfig (type %UserProfile%\\.wslconfig) else (echo nessun .wslconfig)" > "$O/wslconfig.txt"
cat "$O/wslconfig.txt"
# wsl --shutdown nella sessione del desktop (da SSH wsl.exe non parte)
printf '%s' "--shutdown" > "$O/args.txt"
sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$O/args.txt" marietto@win11:'C:/claude/wsl-args.txt'
w "del C:\\claude\\wsl-log.txt 2>nul & schtasks /create /tn claude-wsl /tr \"powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn claude-wsl >nul"
i=0
while [ $i -lt 30 ]; do w "type C:\\claude\\wsl-log.txt" | grep -q codice && break; sleep 10; i=$((i + 1)); done
w "type C:\\claude\\wsl-log.txt" > "$O/shutdown.txt"
sleep 20
sudo -n dtrace -s "$B/dtrace/win-wslcfg.d" -o "$O/minuti.txt" 2>"$O/dtrace.err" &
sh "$C/ramwsl.sh" "$O/ram.txt" &
RP=$!
sh "$C/kb-ab.sh" "$E"
[ -n "$RP" ] && kill "$RP"
sudo -n pkill -f "win-wslcfg.d"
w "type C:\\claude\\wsl-log.txt" > "$O/wsl-log-ultimo.txt"
echo "OUTPUT $O"
