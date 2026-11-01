#!/bin/bash
# Claude 21/10/2026: prova dell'immediate exit (41e71d7). Stessa finestra di carico
# della fase A (stress-ng cpu+vm con verifica, qui 15 min) con clockmon in parallelo.
L=/mnt/c/claude/faseA
exec > "$L/stress15.log" 2>&1
cd /root || exit 1
./clockmon 1000 > "$L/clockmon-imm.log" 2>&1 &
CM=$!
echo "=== $(date -u) stress-ng 15 min"
stress-ng --cpu 2 --vm 2 --vm-bytes 512M --verify --timeout 15m --metrics-brief
echo "stress-ng rc=$?"
[ -n "$CM" ] && kill "$CM"
wait "$CM"
echo STRESS15-FINE
