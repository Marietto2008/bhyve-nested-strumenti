#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-ept12plain-fix.sh.non-conforme
echo "INERTE: run-ept12plain-fix.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-ept12plain-fix.sh.non-conforme" >&2; exit 4
# run-ept12plain-fix.sh -- Claude 26/10/2026, parere #76 §5: UNA SOLA corsa di
# ept12_remap ordinario col test fail-closed (kut f4a29d65, vmxc-plain.flat),
# traccia diag77.d (sonda ricavata al momento, contesto legato, verdetti L0).
# Da lanciare SOLO con l'assenso esplicito dell'utente per QUESTA corsa.
# Nessun retry, nessuna corsa successiva, nessun cambio di kernel/flag.
W=/mnt/linuxulator2/vm/wsl2/linux
T=$W/freebsd-nested/tools/nested
cd $W || exit 1
MOD=/boot/kernel/vmm-restore.ko
MOD_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9
FLAT=$W/kut/vmxc-plain.flat
FLAT_SHA=848b0410e94ca86be1b06a7288f6c80c1de8f3e90eec4a2872e49afbade5c7a5
# RIP dal disassemblato di vmxc-plain.elf (9b87c5f4...): la sonda NON si passa,
# la ricava diag77 dalla violation a questi RIP
RIP_LETTURA0=0x40fb5b	# lettura stage0
RIP_SCRITTURA2=0x40fcbf	# e12_s2_write
D77_SHA=52875b1cdd87496ad814428bb8df357eae8055e7eedbebecefa04851c7adaaaf
RIP_LETTURA=0x40fca1	# e12_s1_read: lettura stage1 in vmxc-plain.elf
EV=$W/evidenze-ept12-rip/corsa-plain-1
mkdir -p $EV || exit 1
[ -e $EV/diag77.out ] && { echo "STOP: corsa gia' fatta ($EV)"; exit 1; }

ferma() { echo "STOP: $*"; sudo -n /sbin/sysctl hw.vmm.vmx.nested_diag58=0 hw.vmm.vmx.nested_diag58_gpa=0 >/dev/null; exit 1; }

echo "=== controlli a freddo ==="
[ "$(/sbin/sha256 -q $MOD)" = "$MOD_SHA" ] || ferma "modulo diverso da 27125f004917"
[ "$(/sbin/sha256 -q $FLAT)" = "$FLAT_SHA" ] || ferma "vmxc-plain.flat diverso da quello rivisto"
[ "$(/sbin/sha256 -q $T/diag77.d)" = "$D77_SHA" ] || ferma "diag77.d diverso da quello collaudato"
[ "$(/sbin/sysctl -n hw.vmm.vmx.vept_keep)" = "0" ] || ferma "vept_keep != 0"
[ "$(/sbin/sysctl -n hw.vmm.vmx.nested_diag58)" = "0" ] || ferma "nested_diag58 gia' acceso"
/sbin/sysctl -n hw.vmm.vmx.nested_invept_opt >/dev/null 2>&1 && ferma "esiste un interruttore di elisione: build inattesa"
{
	echo "modulo $MOD_SHA"; echo "flat   $FLAT_SHA"
	echo "diag77.d $(/sbin/sha256 -q $T/diag77.d)"
	echo "lista  $(/sbin/sha256 -q $T/kut-ept12plain-fix.list)"
	sudo -n /usr/sbin/cpucontrol -m 0x8b /dev/cpuctl6
	sudo -n /usr/sbin/cpucontrol -i 0x1 /dev/cpuctl6
	/sbin/sysctl kern.osrelease hw.vmm.vmx.vept_keep hw.vmm.vmx.vept_diag
} > $EV/baseline.txt 2>&1
/bin/cat $EV/baseline.txt

echo "=== audit VM (vista root) ==="
vivi=$(sudo -n /bin/ps axww -o pid,ppid,user,command | /usr/bin/grep -iE 'bhyve|qemu-system' | /usr/bin/grep -v grep)
[ -n "$vivi" ] && { echo "$vivi"; ferma "processo VM vivo"; }
for v in /dev/vmm/*; do
	[ -e "$v" ] || continue
	aperti=$(sudo -n /usr/bin/fstat "$v" 2>/dev/null | /usr/bin/sed 1d)
	[ -n "$aperti" ] && { echo "$aperti"; ferma "$v e' aperto da un processo"; }
done
echo "audit: nessuna VM viva, nessun /dev/vmm aperto"

echo "=== traccia ==="
sudo -n /sbin/sysctl hw.vmm.vmx.nested_diag58_gpa=0 hw.vmm.vmx.nested_diag58=1 || ferma "sysctl diag58"
: > $EV/diag77.out
sudo -n /usr/sbin/dtrace -s $T/diag77.d $RIP_LETTURA $RIP_LETTURA0 $RIP_SCRITTURA2 -o $EV/diag77.out 2> $EV/diag77.err &
DT=$!
i=0
until /usr/bin/grep -q '== TRACCIA PRONTA ==' $EV/diag77.out 2>/dev/null; do
	i=$((i + 1))
	[ $i -gt 30 ] && { sudo -n kill -TERM $DT; ferma "DTrace non pronto in 15 s"; }
	sleep 0.5
done

echo "=== corsa (una) ==="
sudo -n env TEST_CPUS=6 /bin/sh $W/kutvpid/kut-run.sh --nested $T/kut-ept12plain-fix.list > $EV/kut-run.out 2>&1
rc=$?
sleep 2
sudo -n kill -TERM $DT
wait $DT 2>/dev/null
sudo -n /sbin/sysctl hw.vmm.vmx.nested_diag58=0 hw.vmm.vmx.nested_diag58_gpa=0
/bin/cat $EV/kut-run.out
echo "kut-run rc=$rc"

echo "=== evidenze ==="
ser=$(/bin/ls -t $W/logs/kut-*-ept12_remap.serial | /usr/bin/head -1)
/bin/cp -n "$ser" $EV/ && echo "serial: $ser"
/usr/bin/grep -E 'E12DIAG|PASS|FAIL|SUMMARY' "$ser"
/usr/bin/grep -q '== TRACCIA CHIUSA ==' $EV/diag77.out && echo "traccia completa ($(/usr/bin/wc -l < $EV/diag77.out) righe)" || echo "TRACCIA TRONCA: INCONCLUSIVO"
echo "-- verdetti L0:"; /usr/bin/grep -E "SONDA RICAVATA|ALLARME|ALTRO CONTESTO|FOGLIA DOPO|RIEPILOGO|^   stage|L0_LEAF|L0_S2" $EV/diag77.out
echo "-- VMCALL (reason 18):"; /usr/bin/grep 'reason=18' $EV/diag77.out
echo "-- violation sonda / lettura:"; /usr/bin/grep 'reason=48' $EV/diag77.out
echo "-- riflessione L0 -> L1:"; /usr/bin/grep REFLECT $EV/diag77.out
echo "-- foglie EPT02 installate sulla sonda:"; /usr/bin/grep INSTALL-SONDA $EV/diag77.out
echo "-- wipe/INVEPT:"; /usr/bin/grep -c 'WIPE' $EV/diag77.out; /usr/bin/grep -c 'INVEPT-fisico' $EV/diag77.out
/sbin/sha256 -r $EV/* > $EV/SHA256SUMS 2>/dev/null
/bin/ls /dev/vmm
echo "FINE: una corsa, nessuna successiva automatica"
