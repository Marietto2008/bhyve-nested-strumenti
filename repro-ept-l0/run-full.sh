#!/bin/sh
# run-full.sh -- Claude 26/10/2026, parere #71: UNA SOLA corsa del Checkpoint B.
# Da lanciare SOLO con l'assenso esplicito dell'utente. Non ripete, non avvia
# altre corse. Uso: run-full.sh N   (N = numero della corsa, per i nomi dei log)
N=${1:-1}
D=/mnt/linuxulator2/vm/nested-work/repro-ept-l0
cd $D || exit 1
BIN=./ept_l0_repro
ATTESO=fc8ff592b3fcd721cd6be489c5e889b479e0c1ece41607a637f9e5d6fd5ccabf
OUT=runB$N.out
TR=runB$N.d.out

ferma() { echo "STOP: $*"; exit 1; }

echo "=== audit VM (vista root) ==="
[ "$(/sbin/sha256 -q $BIN)" = "$ATTESO" ] || ferma "binario diverso dalla v5 rivista"
[ "$(/sbin/sysctl -n hw.vmm.vmx.nested_diag58)" = "0" ] || ferma "nested_diag58 != 0"
[ -e /dev/vmm/claude-eptrepro ] && ferma "esiste gia' claude-eptrepro"
/bin/ls -l /dev/vmm
# 1) processi il cui comando nomina bhyve/qemu (il bhyve dell'host ha un nome diverso)
vivi=$(sudo -n /bin/ps axww -o pid,ppid,user,command | /usr/bin/grep -iE 'bhyve|qemu-system' | /usr/bin/grep -v grep)
if [ -n "$vivi" ]; then
	echo "$vivi"
	for p in $(echo "$vivi" | /usr/bin/awk '{print $1}'); do sudo -n /usr/bin/procstat -f $p 2>/dev/null | /usr/bin/grep -i vmm; done
	ferma "processo VM vivo"
fi
# 2) chi ha APERTO ogni device /dev/vmm/* (indipendente dal nome del processo)
for v in /dev/vmm/*; do
	[ -e "$v" ] || continue
	aperti=$(sudo -n /usr/bin/fstat "$v" 2>/dev/null | /usr/bin/sed 1d)
	[ -n "$aperti" ] && { echo "$aperti"; ferma "$v e' aperto da un processo"; }
done
echo "audit: nessuna VM viva, nessun /dev/vmm aperto"

echo "=== traccia DTrace (corsa $N) ==="
: > $TR
sudo -n /usr/sbin/dtrace -s ept_l0_repro.d -o $TR 2> $TR.err &
DT=$!
i=0
until /usr/bin/grep -q '== TRACCIA PRONTA ==' $TR 2>/dev/null; do
	i=$((i + 1))
	[ $i -gt 30 ] && { sudo -n kill -TERM $DT; ferma "DTrace non pronto in 15 s"; }
	sleep 0.5
done
echo "traccia pronta (pid sudo $DT)"

echo "=== corsa $N ==="
if sudo -n /usr/bin/timeout -k 5 120 /usr/bin/cpuset -l 6 $BIN > $OUT 2>&1; then
	rc=0
else
	rc=$?
fi
sleep 2
sudo -n kill -TERM $DT
wait $DT 2>/dev/null
printf 'exit status: %s\n' "$rc"
/bin/cat $OUT

echo "=== chiusura traccia ==="
if /usr/bin/grep -q '== TRACCIA CHIUSA ==' $TR; then
	echo "traccia completa ($( /usr/bin/wc -l < $TR ) righe)"
else
	echo "TRACCIA TRONCA: verdetto hardware = UNOBSERVED"
fi

echo "=== evidenze hardware dalla traccia ==="
echo "eptp distinti (deve essere 1): $(/usr/bin/grep ' ENTRY ' $TR | /usr/bin/sed -E 's/.*eptp=([0-9a-fx]+).*/\1/' | /usr/bin/sort -u | /usr/bin/wc -l)"
echo "pm_pmltop distinti (deve essere 1): $(/usr/bin/grep ' ENTRY ' $TR | /usr/bin/sed -E 's/.*pm_pmltop=([0-9a-fx]+).*/\1/' | /usr/bin/sort -u | /usr/bin/wc -l)"
echo "cpu distinte (deve essere 1): $(/usr/bin/grep -E ' (ENTRY|EXIT) ' $TR | /usr/bin/sed -E 's/.* cpu([0-9]+) .*/\1/' | /usr/bin/sort -u | /usr/bin/tr '\n' ' ')"
echo "ingressi con INVEPT dovuto: $(/usr/bin/grep -c 'INVEPT DOVUTO' $TR)"
echo "reason48 -> PAGING su X:    $(/usr/bin/grep -c 'REASON48 -> PAGING' $TR)"
echo "reason48 -> INST_EMUL su X: $(/usr/bin/grep -c 'REASON48 -> INST_EMUL' $TR)"

echo "=== post-controlli ==="
if [ -e /dev/vmm/claude-eptrepro ]; then
	echo "ATTENZIONE: VM di test ancora presente (cleanup NON avvenuto)"
else
	echo "VM di test distrutta: OK"
fi
/bin/ls /dev/vmm
echo "FINE CORSA $N -- nessuna corsa successiva automatica"
