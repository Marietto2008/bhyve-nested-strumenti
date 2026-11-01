#!/bin/sh
# Claude 26/10/2026 -- parere #58 §4: gancio diagnostico diag58 (8862eedd9494)
# SOLO lettura, spento di default, sopra la 216f0f725c5d caricata. NON riavvia.
# --ritorno torna a 216f0f725c5d. Richiede riavvio esplicito dell'utente dopo.
set -eu
B=/mnt/linuxulator2/vm/wsl2/fbsd; K=/boot/kernel/vmm-restore.ko
PREV=4ca4c1abc1ef7f0ee1a19bba6d97a8806a87f31012fe75de5bf322ed6765beb7	# 216f0f725c5d
NUOVO=b4d64537f9874fb5f5f9afbc12dac59338f83ef89121f8f68d0a14c7e47c9958	# diag58 8862eedd9494
SRC=$B/stage/diag58-8862eedd9494/vmm-restore.ko
if [ "${1:-}" = "--ritorno" ]; then
	[ "$(sha256 -q $K.216f0f725c5d)" = "$PREV" ] || { echo "copia 216f0f725c5d assente o diversa"; exit 1; }
	install -m 555 $K.216f0f725c5d $K; cp $K.216f0f725c5d $B/stage/current/vmm-restore.ko
	echo "ritorno a 216f0f725c5d: $(sha256 -q $K)"; exit 0
fi
[ "$(sha256 -q $K)" = "$PREV" ] || { echo "in /boot non c'e' 216f0f725c5d: mi fermo"; exit 1; }
[ "$(sha256 -q $SRC)" = "$NUOVO" ] || { echo "nello stage non c'e' diag58: mi fermo"; exit 1; }
[ -e $K.216f0f725c5d ] || cp -p $K $K.216f0f725c5d
[ "$(sha256 -q $K.216f0f725c5d)" = "$PREV" ] || { echo "copia di ritorno non verificata: mi fermo"; exit 1; }
if /usr/bin/grep -qE "nested_vpid|nested_shadow|nested_fast|nested_invept" /boot/loader.conf /boot/loader.conf.local 2>/dev/null; then
	echo "loader.conf imposta interruttori nested: mi fermo"; exit 1
fi
install -m 555 $SRC $K; cp $SRC $B/stage/current/vmm-restore.ko
echo "installato: $(sha256 -q $K) (atteso $NUOVO)"; echo "ritorno: $K.216f0f725c5d"
echo "ORA SERVE IL RIAVVIO (deciso dall'utente). diag58 spento: sysctl hw.vmm.vmx.nested_diag58=1 per accendere."
