#!/bin/sh
# run-smoke.sh -- Claude 26/10/2026, parere #70 Checkpoint A: SOLO lo smoke test.
# Da lanciare SOLO dopo l'autorizzazione esplicita dell'utente.
# Non avvia nessuna fase successiva.
cd /mnt/linuxulator2/vm/wsl2/fbsd/repro-ept-l0 || exit 1
BIN=./ept_l0_repro
ATTESO=667b3f3a68a11090c10139e5b0c99c11dad7057cfe3f5e0e94d857dba795e249	# v4

echo "=== pre-controlli ==="
[ "$(sha256 -q $BIN)" = "$ATTESO" ] || { echo "binario diverso dalla v3 rivista: mi fermo"; exit 1; }
[ "$(sysctl -n hw.vmm.vmx.nested_diag58)" = "0" ] || { echo "nested_diag58 != 0: mi fermo"; exit 1; }
if [ -e /dev/vmm/claude-eptrepro ]; then echo "esiste gia' claude-eptrepro: mi fermo"; exit 1; fi
# Il bhyve di questo host NON si chiama "bhyve" (es. bhyve-hlt-mirrorfix):
# niente corrispondenza esatta, si cerca per sottostringa su comando e argomenti,
# con la vista di root. Qualunque VM viva = mi fermo.
vivi=$(sudo -n ps -ax -o pid,comm,args | grep -iE 'bhyve|qemu-system' | grep -v grep)
if [ -n "$vivi" ]; then
	echo "c'e' una VM in esecuzione: mi fermo"; echo "$vivi"; exit 1
fi
# Ogni voce di /dev/vmm deve essere senza processo che la nomina.
for v in $(ls /dev/vmm 2>/dev/null); do
	if sudo -n ps -ax -o args | grep -F ": $v" | grep -qv grep; then
		echo "la VM $v ha un processo vivo: mi fermo"; exit 1
	fi
done
echo "VM presenti prima (nessuna con processo): $(ls /dev/vmm 2>/dev/null | tr '\n' ' ')"

echo "=== smoke ==="
if sudo -n timeout -k 5 60 cpuset -l 6 $BIN smoke > run.smoke.out 2>&1; then
	rc=0
else
	rc=$?
fi
printf 'smoke exit status: %s\n' "$rc"
cat run.smoke.out

echo "=== post-controlli ==="
if [ -e /dev/vmm/claude-eptrepro ]; then
	echo "ATTENZIONE: VM di test ancora presente (cleanup NON avvenuto)"
else
	echo "VM di test distrutta: OK"
fi
echo "VM presenti dopo: $(ls /dev/vmm 2>/dev/null | tr '\n' ' ')"

ok=1
[ "$rc" = "0" ] || ok=0
grep -q '^RISULTATO: SMOKE PASS$' run.smoke.out || ok=0
grep -q 'EAX=0x41414141 inout.eax=0x41414141' run.smoke.out || ok=0
[ -e /dev/vmm/claude-eptrepro ] && ok=0
if [ "$ok" = "1" ]; then
	echo "CHECKPOINT A: SMOKE PASS (rc=0, SMOKE PASS, EAX=0x41414141, cleanup ok)"
else
	echo "CHECKPOINT A: INVALID (rc=$rc) -- nessuna fase successiva"
fi
