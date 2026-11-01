#!/bin/bash
# Claude 22/10/2026 -- parere #30: buchi dell'orologio durante l'I/O. clockmon in
# parallelo a 3 cicli di io.sh (ext4 + NTFS via /mnt/c, SHA-256).
L=/mnt/c/claude/faseA
exec > "$L/iogap.log" 2>&1
cd /root || exit 1
tr -d '\r' < "$L/io.sh" > io.sh
./clockmon 1800 > "$L/clockmon-iogap.log" 2>&1 &
CM=$!
echo "=== $(date -u) io"
bash io.sh 3
echo "=== $(date -u) fine"
[ -n "$CM" ] && kill "$CM"
wait "$CM"
echo IOGAP-FINE
