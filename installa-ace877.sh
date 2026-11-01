#!/bin/sh
# Claude 25/10/2026 -- parere #51 §11 passo 06: installa la revisione diagnostica ace877c6dd48 sopra
# la 22ad8106199e attualmente caricata. Copia di ritorno verificata. NON riavvia.
# uso: sudo -n sh installa-ace877.sh        ritorno: sudo -n sh installa-ace877.sh --ritorno
set -eu
B=/mnt/linuxulator2/vm/wsl2/linux
K=/boot/kernel/vmm-restore.ko
VAL=d2ddea7f7d0d978a57089cb69c8654aca745140f003fd61e073eb90643d2a47e	# 22ad8106199e (validato)
NUOVO=aeb179f81e97e172f85381b6ff39797bd439964a0ffaf0672ca7917a1a6d22a2	# ace877c6dd48 (diagnostico)
SRC=$B/stage/ace877c6dd48-vpid-diag/vmm-restore.ko
if [ "${1:-}" = "--ritorno" ]; then
	[ "$(sha256 -q $K.22ad8106199e)" = "$VAL" ] || { echo "copia 22ad8106199e assente o diversa"; exit 1; }
	install -m 555 $K.22ad8106199e $K
	cp $K.22ad8106199e $B/stage/current/vmm-restore.ko
	echo "ritorno a 22ad8106199e: $(sha256 -q $K)"; exit 0
fi
[ "$(sha256 -q $K)" = "$VAL" ] || { echo "in /boot non c'e' 22ad8106199e: mi fermo"; exit 1; }
[ "$(sha256 -q $SRC)" = "$NUOVO" ] || { echo "nello stage non c'e' ace877c6dd48: mi fermo"; exit 1; }
[ -e $K.22ad8106199e ] || cp -p $K $K.22ad8106199e
[ "$(sha256 -q $K.22ad8106199e)" = "$VAL" ] || { echo "copia di ritorno non verificata: mi fermo"; exit 1; }
if /usr/bin/grep -qE "nested_vpid|nested_shadow|nested_fast" /boot/loader.conf /boot/loader.conf.local 2>/dev/null; then
	echo "loader.conf imposta interruttori nested: mi fermo"; exit 1
fi
install -m 555 $SRC $K
cp $SRC $B/stage/current/vmm-restore.ko
echo "installato: $(sha256 -q $K) (atteso $NUOVO)"
echo "copia di ritorno: $K.22ad8106199e (e $K.19fc4ebf6189)"
