#!/bin/sh
# Claude 26/10/2026 -- parere #60 §8: diag58 esteso (27125f004917), SOLO lettura,
# spento di default, sopra diag58 b4d64537 o 216f0f. NON riavvia. --ritorno -> 216f0f.
set -eu
B=/mnt/linuxulator2/vm/nested-work; K=/boot/kernel/vmm-restore.ko
BASE=4ca4c1abc1ef7f0ee1a19bba6d97a8806a87f31012fe75de5bf322ed6765beb7	# 216f0f725c5d (rollback)
OLD=b4d64537f9874fb5f5f9afbc12dac59338f83ef89121f8f68d0a14c7e47c9958	# diag58 8862eedd9494
NUOVO=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9	# diag58ext 27125f004917
SRC=$B/stage/diag58ext-27125f004917/vmm-restore.ko
if [ "${1:-}" = "--ritorno" ]; then
	[ "$(sha256 -q $K.216f0f725c5d)" = "$BASE" ] || { echo "backup 216f0f assente/diverso"; exit 1; }
	install -m 555 $K.216f0f725c5d $K; cp $K.216f0f725c5d $B/stage/current/vmm-restore.ko
	echo "ritorno a 216f0f725c5d: $(sha256 -q $K)"; exit 0
fi
cur=$(sha256 -q $K)
case "$cur" in
	"$OLD"|"$BASE") ;;
	*) echo "in /boot c'e' $cur: non e' ne diag58 ne 216f0f, mi fermo"; exit 1;;
esac
[ "$(sha256 -q $SRC)" = "$NUOVO" ] || { echo "nello stage non c'e' diag58ext, mi fermo"; exit 1; }
[ -e $K.216f0f725c5d ] && [ "$(sha256 -q $K.216f0f725c5d)" = "$BASE" ] || { echo "backup 216f0f mancante/diverso, mi fermo"; exit 1; }
if /usr/bin/grep -qE "nested_vpid|nested_shadow|nested_fast|nested_invept" /boot/loader.conf /boot/loader.conf.local 2>/dev/null; then
	echo "loader.conf imposta interruttori nested: mi fermo"; exit 1
fi
install -m 555 $SRC $K; cp $SRC $B/stage/current/vmm-restore.ko
echo "installato: $(sha256 -q $K) (atteso $NUOVO)"; echo "ritorno: $K.216f0f725c5d (installa-diag58ext.sh --ritorno)"
echo "ORA SERVE IL RIAVVIO. Poi: sysctl hw.vmm.vmx.nested_diag58=1 e nested_diag58_gpa=<GPA sonda>."
