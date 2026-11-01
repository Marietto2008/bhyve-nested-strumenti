#!/bin/sh
# Claude 21/10/2026: memoria della VM di WSL (vmmemWSL) ogni 60 s, con l'ora. uso: ramwsl.sh <file>
F="${1:?file}"
while pgrep -x bhyve >/dev/null; do
	r=$(sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o LogLevel=ERROR marietto@win11 \
	    "powershell -NoProfile -Command \"(Get-Process | ? { \$_.Name -like 'vmmem*' } | Measure-Object WorkingSet64 -Sum).Sum / 1MB\"" 2>/dev/null | tr -d '\r')
	echo "$(date '+%H:%M:%S') vmmemWSL_MB=${r:-?}" >> "$F"
	sleep 60
done
