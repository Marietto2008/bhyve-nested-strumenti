#!/bin/sh
# Claude 25/10/2026 -- parere #50 §9 passo 01: installa il modulo 22ad8106199e (tracciamento VPID,
# interruttori spenti per default) al posto di 19fc4ebf6189, con copia di ritorno verificata.
# NON riavvia e NON carica nulla: il modulo nuovo entra al prossimo riavvio, deciso dall'utente.
# uso: sudo -n sh installa-22ad.sh      ritorno: sudo -n sh installa-22ad.sh --ritorno
set -eu
B=/mnt/linuxulator2/vm/nested-work
K=/boot/kernel/vmm-restore.ko
VECCHIO=52046f6384b0fc539af4c55d10a8259ac69ad0d2101b0ea7007e787f7603175b	# 19fc4ebf6189
NUOVO=d2ddea7f7d0d978a57089cb69c8654aca745140f003fd61e073eb90643d2a47e	# 22ad8106199e
SRC=$B/stage/22ad8106199e-vpid-track-49/vmm-restore.ko
if [ "${1:-}" = "--ritorno" ]; then
	[ "$(sha256 -q $K.19fc4ebf6189)" = "$VECCHIO" ] || { echo "copia 19fc4ebf6189 assente o diversa"; exit 1; }
	install -m 555 $K.19fc4ebf6189 $K
	cp $K.19fc4ebf6189 $B/stage/current/vmm-restore.ko
	echo "ritorno a 19fc4ebf6189: $(sha256 -q $K)"; exit 0
fi
[ "$(sha256 -q $K)" = "$VECCHIO" ] || { echo "il modulo in /boot non e' 19fc4ebf6189: mi fermo"; exit 1; }
[ "$(sha256 -q $SRC)" = "$NUOVO" ] || { echo "il modulo nello stage non e' 22ad8106199e: mi fermo"; exit 1; }
[ -e $K.19fc4ebf6189 ] || cp -p $K $K.19fc4ebf6189
[ "$(sha256 -q $K.19fc4ebf6189)" = "$VECCHIO" ] || { echo "copia di ritorno non verificata: mi fermo"; exit 1; }
[ -e $B/stage/current/vmm-restore.ko.19fc4ebf6189 ] || cp -p $B/stage/current/vmm-restore.ko $B/stage/current/vmm-restore.ko.19fc4ebf6189
if /usr/bin/grep -qE "nested_vpid|nested_shadow|nested_fast" /boot/loader.conf /boot/loader.conf.local 2>/dev/null; then
	echo "loader.conf imposta interruttori nested: mi fermo"; exit 1
fi
install -m 555 $SRC $K
cp $SRC $B/stage/current/vmm-restore.ko
echo "installato: $(sha256 -q $K) (atteso $NUOVO)"
echo "copia di ritorno: $K.19fc4ebf6189"
