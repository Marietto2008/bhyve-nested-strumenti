#!/bin/sh
# Claude 25/10/2026 -- revisione D4 728bfc544720 sopra la diagnostica ace877c6dd48 attualmente
# caricata. Copia di ritorno verificata. NON riavvia.
# uso: sudo -n sh installa-728bfc.sh        ritorno: sudo -n sh installa-728bfc.sh --ritorno
set -eu
B=/mnt/linuxulator2/vm/nested-work
K=/boot/kernel/vmm-restore.ko
PREV=aeb179f81e97e172f85381b6ff39797bd439964a0ffaf0672ca7917a1a6d22a2	# ace877c6dd48
NUOVO=d102b77897865ee7ea97214715976430e6a5fc71e707f0ce3b62c5b66f9a92b4	# 728bfc544720
SRC=$B/stage/728bfc544720-vpid-diag2/vmm-restore.ko
if [ "${1:-}" = "--ritorno" ]; then
	[ "$(sha256 -q $K.ace877c6dd48)" = "$PREV" ] || { echo "copia ace877c6dd48 assente o diversa"; exit 1; }
	install -m 555 $K.ace877c6dd48 $K
	cp $K.ace877c6dd48 $B/stage/current/vmm-restore.ko
	echo "ritorno a ace877c6dd48: $(sha256 -q $K)"; exit 0
fi
[ "$(sha256 -q $K)" = "$PREV" ] || { echo "in /boot non c'e' ace877c6dd48: mi fermo"; exit 1; }
[ "$(sha256 -q $SRC)" = "$NUOVO" ] || { echo "nello stage non c'e' 728bfc544720: mi fermo"; exit 1; }
[ -e $K.ace877c6dd48 ] || cp -p $K $K.ace877c6dd48
[ "$(sha256 -q $K.ace877c6dd48)" = "$PREV" ] || { echo "copia di ritorno non verificata: mi fermo"; exit 1; }
if /usr/bin/grep -qE "nested_vpid|nested_shadow|nested_fast" /boot/loader.conf /boot/loader.conf.local 2>/dev/null; then
	echo "loader.conf imposta interruttori nested: mi fermo"; exit 1
fi
install -m 555 $SRC $K
cp $SRC $B/stage/current/vmm-restore.ko
echo "installato: $(sha256 -q $K) (atteso $NUOVO)"
echo "ritorno: $K.ace877c6dd48 (e .22ad8106199e, .19fc4ebf6189)"
