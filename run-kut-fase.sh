#!/bin/sh
# Claude 24/10/2026 -- parere #45 §7: una FASE della sessione di test del modulo 19fc4ebf6189.
# Esegue in sequenza le liste kvm-unit-tests principali (--nested) con gli interruttori S0 /
# shadow impostati dal chiamante, e raccoglie in logs/kutfase-<etichetta>-<ora>/:
#   esiti.txt   una riga per test (lista, nome, verdetto, SUMMARY)
#   sysctl-prima.txt / sysctl-dopo.txt   contatori nested_ffv_* e nested_sh_* (e i valori degli
#               interruttori) prima e dopo, per vedere se lo shadow ha lavorato e se ci sono errori
# uso: sudo -n sh run-kut-fase.sh <etichetta> [liste...]
E=${1:?etichetta}; shift
B=/mnt/linuxulator2/vm/wsl2/fbsd; N=$B/freebsd-nested/tools/nested
LISTE=${*:-"f1 f2a f2b f2c b1 efersave immexit invept persist"}
O=$B/logs/kutfase-$E-$(date +%Y%m%d-%H%M); mkdir -p "$O"
foto() { sysctl hw.vmm.vmx | /usr/bin/grep -E "\.nested_(ffv|sh|fast|shadow)" > "$O/$1"; }
foto sysctl-prima.txt
echo "fase $E, liste: $LISTE, inizio $(date +%T)" | tee "$O/esiti.txt"
for L in $LISTE; do
	before=$(ls -t $B/logs/kut-*-riassunto.txt 2>/dev/null | head -1)
	sh "$N/kut-run.sh" --nested "$N/kut-$L.list" > "$O/kut-$L.out" 2>&1
	after=$(ls -t $B/logs/kut-*-riassunto.txt 2>/dev/null | head -1)
	if [ "$after" != "$before" ] && [ -n "$after" ]; then
		sed "s/^/$L /" "$after" >> "$O/esiti.txt"
	else
		echo "$L NESSUN-RIASSUNTO" >> "$O/esiti.txt"
	fi
	echo "  $L: $(/usr/bin/grep -c " PASS " "$after" 2>/dev/null) PASS su $(wc -l < "$after" 2>/dev/null) ($(date +%T))"
	dmesg | tail -3 | /usr/bin/grep -i "nested shadow\|panic" && echo "!!! messaggio dal kernel dopo $L"
done
foto sysctl-dopo.txt
echo "fine $(date +%T)" >> "$O/esiti.txt"
echo "OUTPUT $O"
