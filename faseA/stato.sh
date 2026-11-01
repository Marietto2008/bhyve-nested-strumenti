#!/bin/sh
# Claude 20/10/2026: stato della fase A (log dal guest + traccia dell'host)
C=/mnt/linuxulator2/vm/wsl2/fbsd/faseA
for f in load.log clockmon.log clockmon-win.log; do
	sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o LogLevel=ERROR \
	    marietto@win11:"C:/claude/faseA/$f" "$C/$f" 2>/dev/null
	echo "== $f"; grep -vE "^\[|^stress-ng: info" "$C/$f" 2>/dev/null | tail -${1:-6}
done
O=$(ls -d /mnt/linuxulator2/vm/wsl2/fbsd/logs/faseA-* | tail -1)
echo "== host ($O)"; pgrep -x bhyve >/dev/null && echo "bhyve vivo" || echo "BHYVE NON GIRA"
grep -c "!!!" "$O/efer.txt"; grep "!!!" "$O/efer.txt" | tail -5
L=$(grep -n "^=== " "$O/efer.txt" | tail -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},\$p" "$O/efer.txt" | grep -v "uscite da L2"
