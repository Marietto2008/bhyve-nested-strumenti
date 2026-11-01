#!/bin/sh
# Claude 21/10/2026: una prova A/B dell'INVEPT selettivo (parere #24). uso: kb-ab.sh <etichetta>
# Con Windows gia' acceso e WSL pronto: traccia host (win-kb.d), tempo CPU di bhyve
# prima e dopo, compilazione del kernel in WSL (kbuild.sh), log in logs/kb-<etichetta>-*.
E="${1:?etichetta}"; KB="${2:-kbuild.sh}"	# script di compilazione (kbuild.sh -j2, kbuild4.sh -j4)
B=/mnt/linuxulator2/vm/wsl2/linux
C="$B/faseA"
O="$B/logs/kb-$E-$(date +%Y%m%d-%H%M)"
mkdir -p "$O"
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
P=$(pgrep -x bhyve)
[ -n "$P" ] || { echo "bhyve non gira"; exit 1; }
sudo -n dtrace -Z -s "$B/dtrace/win-kb.d" -o "$O/host.txt" 2>"$O/dtrace.err" &
ps -o time= -p "$P" > "$O/cpu-prima.txt"; date +%s > "$O/t-prima.txt"
sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$C/$KB" marietto@win11:"C:/claude/faseA/$KB"
printf '%s' "-d Debian -u root -- bash -c 'tr -d \"\\\\r\" < /mnt/c/claude/faseA/$KB > /root/$KB; bash /root/$KB'" > "$O/args.txt"
sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$O/args.txt" marietto@win11:'C:/claude/wsl-args.txt'
w "del C:\\claude\\faseA\\kbuild.log 2>nul & del C:\\claude\\wsl-log.txt 2>nul & schtasks /create /tn claude-wsl /tr \"powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn claude-wsl"
until sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o LogLevel=ERROR \
    marietto@win11:'C:/claude/faseA/kbuild.log' "$O/kbuild.log" 2>/dev/null && grep -q KBUILD-FINE "$O/kbuild.log"; do
	pgrep -x bhyve >/dev/null || { echo "BHYVE USCITO"; break; }
	sleep 60
done
ps -o time= -p "$P" > "$O/cpu-dopo.txt"; date +%s > "$O/t-dopo.txt"
sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR marietto@win11:'C:/claude/faseA/clockmon-kbuild.log' "$O/clockmon.log"
sudo -n pkill -f "win-kb.d"
sleep 2
echo "== $E"; grep -E "real|user|sys|kernel rc" "$O/kbuild.log"
echo "bhyve CPU: $(cat "$O/cpu-prima.txt") -> $(cat "$O/cpu-dopo.txt"), parete $(( $(cat "$O/t-dopo.txt") - $(cat "$O/t-prima.txt") )) s"
grep -E "cumulativo|radici|tipo" "$O/host.txt" | tail -5
echo "OUTPUT $O"
