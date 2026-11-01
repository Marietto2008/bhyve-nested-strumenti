#!/bin/sh
# Claude 25/10/2026 -- parere #53 §8: strumentazione INVEPT 216f0f725c5d sopra la 728bfc544720 caricata.
# Solo contatori, nessun cambio di comportamento. NON riavvia. --ritorno torna a 728bfc544720.
set -eu
B=/mnt/linuxulator2/vm/wsl2/linux; K=/boot/kernel/vmm-restore.ko
PREV=d102b77897865ee7ea97214715976430e6a5fc71e707f0ce3b62c5b66f9a92b4	# 728bfc544720
NUOVO=4ca4c1abc1ef7f0ee1a19bba6d97a8806a87f31012fe75de5bf322ed6765beb7	# 216f0f725c5d
SRC=$B/stage/216f0f725c5d-invept-instr/vmm-restore.ko
if [ "${1:-}" = "--ritorno" ]; then
	[ "$(sha256 -q $K.728bfc544720)" = "$PREV" ] || { echo "copia 728bfc544720 assente o diversa"; exit 1; }
	install -m 555 $K.728bfc544720 $K; cp $K.728bfc544720 $B/stage/current/vmm-restore.ko
	echo "ritorno a 728bfc544720: $(sha256 -q $K)"; exit 0
fi
[ "$(sha256 -q $K)" = "$PREV" ] || { echo "in /boot non c'e' 728bfc544720: mi fermo"; exit 1; }
[ "$(sha256 -q $SRC)" = "$NUOVO" ] || { echo "nello stage non c'e' 216f0f725c5d: mi fermo"; exit 1; }
[ -e $K.728bfc544720 ] || cp -p $K $K.728bfc544720
[ "$(sha256 -q $K.728bfc544720)" = "$PREV" ] || { echo "copia di ritorno non verificata: mi fermo"; exit 1; }
if /usr/bin/grep -qE "nested_vpid|nested_shadow|nested_fast|nested_invept" /boot/loader.conf /boot/loader.conf.local 2>/dev/null; then
	echo "loader.conf imposta interruttori nested: mi fermo"; exit 1
fi
install -m 555 $SRC $K; cp $SRC $B/stage/current/vmm-restore.ko
echo "installato: $(sha256 -q $K) (atteso $NUOVO)"; echo "ritorno: $K.728bfc544720"
