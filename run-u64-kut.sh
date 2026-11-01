#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-u64-kut.sh.non-conforme
echo "INERTE: run-u64-kut.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-u64-kut.sh.non-conforme" >&2; exit 4
# run-u64-kut.sh (v2) -- Claude 31/10/2026, pareri #166-#167R1 (livello A1 del dossier). UNA sessione KUT u64 sul modulo
# ORIGINALE: nessuno scambio di modulo, nessun nesting (accel bhyve SENZA nested=on), una VM (vm2), 1 vCPU su CPU 6.
#
#   run-u64-kut.sh --prova  <out>    solo controlli in sola lettura + il comando che userebbe: NESSUNA VM
#   run-u64-kut.sh --esegui <out>    UNA sessione (consenso dell'utente); nessun rilancio
#
# La finestra di misura (#167R1 §4): "U64 PRONTO" -> fotografia (bhyvectl --get-stats) e SOLO se riuscita 'g';
# il record finale UNIVOCO "U64 FINE casi=..." -> fotografia e SOLO se riuscita 'f' (il guest aspetta). Il verdetto
# lo da' u64-verdetto.py (28 casi univoci, record coerente, fotografie rc 0 con contatori unici e numerici, codice
# KUT decodificato, finestra +0/+0).
# USCITA: quella di u64-verdetto.py (0 MODELLO, 1 CONTRARIO, 3 NON_NATIVA, 5 INCONCLUSIVO); 4 STOP ai controlli.
set -u
B=/mnt/linuxulator2/vm/nested-work
MOD=/boot/kernel/vmm-restore.ko
MOD_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9
OIDS="hw.vmm.vmx.nested_ept12_viol_emul_reflected hw.vmm.vmx.vept_h2_viol_final hw.vmm.gla2gpa_restart_capped hw.vmm.fatal_latches"
OID_ATTESO=0000				# originale: nessuno degli oid dei moduli di prova
FLAT=$B/logs/kut-opnd-build-166/x86/u64.flat
FLAT_SHA=308bc5c74c394fcebf1e829996e7218126880185cbbfc5b6a780703fc9e9eeb3
DRV=$B/kut-drive.py
DRV_SHA=fa4da538e95f01ba05e439f6dc4229e76417e57fdf87408d627b5e320d69fb79
VER=$B/u64-verdetto.py
VER_SHA=8cb0be200ce1639081f9c3fd299eab29ddcd52b62e9e52349f251477200578dd
QEMU=$B/build-qemu-gate-nested-sr/qemu-system-x86_64
QEMU_SHA=650a2bdec6f0fb61ec19066dcd13edd0b647267fd0cec2d0ce8974124b08859a
LIBV_ATTESA=/usr/lib/libvmmapi.so.7
LIBV_SHA=116a74309070a59eb571a8ae44411b482baa148f8398032211a129053bb7c14e
LOADER_SHA=4f3d0c57da4372da8cb501096aa45c359edebf7c11e061c8996e314898022230
PCBIOS=$B/qemu-nested/pc-bios
MACCHINA=pc-i440fx-10.2
PY=/usr/local/bin/python3
TMO=180
LIMITE_BLOCCHI=2097152

[ $# -eq 2 ] || { echo "uso: $0 --prova|--esegui <out>"; exit 4; }
MODO=$1; OUT=$2
ferma() { echo "STOP: $*"; exit 4; }
case "$MODO" in --prova|--esegui) ;; *) ferma "modo $MODO";; esac
case "$OUT" in /*) ;; *) OUT=$(pwd)/$OUT;; esac
case "$OUT" in /mnt/linuxulator2/vm/nested-work/logs/*) ;; *) ferma "uscita fuori da nested-work/logs: $OUT";; esac
[ -e "$OUT" ] && ferma "$OUT esiste gia': nessuna sovrascrittura"
[ "$(df -T "$(dirname "$OUT")" | awk 'NR==2{print $2}')" = zfs ] || ferma "uscita non su ZFS"
ulimit -f $LIMITE_BLOCCHI

echo "=== preflight (sola lettura) ==="
CAR=$(/sbin/kldstat -v -n vmm-restore.ko 2>/dev/null | sed -n 's/.*vmm-restore\.ko (\(.*\))$/\1/p' | head -1)
[ "$CAR" = "$MOD" ] || ferma "caricato '$CAR', atteso $MOD"
[ "$(sha256 -q "$MOD")" = "$MOD_SHA" ] || ferma "modulo diverso dall'originale"
sig=""; for o in $OIDS; do sig=$sig$(/sbin/sysctl -n $o >/dev/null 2>&1 && echo 1 || echo 0); done
[ "$sig" = "$OID_ATTESO" ] || ferma "firma oid $sig, attesa $OID_ATTESO (modulo originale)"
[ "$(sha256 -q /boot/loader.conf)" = "$LOADER_SHA" ] || ferma "loader.conf cambiato"
[ "$(sha256 -q "$FLAT")" = "$FLAT_SHA" ] || ferma "u64.flat diversa da quella congelata"
for x in 'U64 ATTESI casi=' 'U64 PRONTO' 'U64 MISURA APERTA' 'U64 CASO' 'U64 FINE casi=' 'U64 CHIUSO'; do strings "$FLAT" | grep -q "$x" || ferma "la .flat non stampa '$x'"; done
[ "$(sha256 -q "$DRV")" = "$DRV_SHA" ] || ferma "kut-drive.py diverso da quello congelato"
[ "$(sha256 -q "$VER")" = "$VER_SHA" ] || ferma "u64-verdetto.py diverso da quello congelato"
[ "$(sha256 -q "$QEMU")" = "$QEMU_SHA" ] || ferma "QEMU diversa da quella protetta"
LIBV=$(sudo -n /usr/bin/ldd "$QEMU" | awk '/libvmmapi/{print $3}')
[ "$LIBV" = "$LIBV_ATTESA" ] && [ "$(sha256 -q "$LIBV")" = "$LIBV_SHA" ] || ferma "libvmmapi $LIBV diversa da quella attesa"
v=$(/bin/ps -ax -o pid= -o comm= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'); [ -n "$v" ] && { echo "$v"; ferma "una VM e' gia' viva"; }
[ -z "$(ls /dev/vmm 2>/dev/null)" ] || ferma "/dev/vmm non vuoto ($(ls /dev/vmm | tr '\n' ' ')): nessuna distruzione implicita"
[ "$(pciconf -l 2>/dev/null | grep -c '^ppt')" = 6 ] || ferma "i ppt legati non sono 6"
kldstat -q -n amdgpu.ko && ferma "amdgpu caricato"

VMCMD="/usr/bin/cpuset -l 6 /usr/bin/timeout -k 1s $((TMO + 30))s $QEMU -L $PCBIOS --no-reboot -nodefaults \
-machine $MACCHINA -accel bhyve -device isa-debug-exit,iobase=0xf4,iosize=0x4 -display none -monitor none \
-chardev stdio,id=u64,mux=off,signal=off -serial chardev:u64 -smp 1 -m 256 -cpu max -kernel $FLAT"
case "$VMCMD" in *nested=on*|*mon:stdio*|*-daemonize*|*vm0*) ferma "riga QEMU non ammessa";; esac
DRVCMD="$PY $DRV --out $OUT/drv --timeout $TMO --regola 'U64 PRONTO|foto|g' --regola 'U64 FINE casi=|foto|f' \
--foto-cmd '/usr/sbin/bhyvectl --vm=vm2 --get-stats' -- $VMCMD"
echo "preflight OK: originale $MOD_SHA (oid $sig), flat $FLAT_SHA, QEMU $QEMU_SHA, libvmmapi $LIBV_SHA"
echo "comando: sudo -n $DRVCMD"
[ "$MODO" = --prova ] && { echo "PROVA: nessuna VM avviata"; exit 0; }

mkdir -p "$OUT" || ferma "mkdir $OUT"
eval sudo -n $DRVCMD > "$OUT/driver.out" 2>&1
DRC=$?
cat "$OUT/driver.out"
echo "driver: uscita $DRC (0 = sessione valida)"
$PY "$VER" "$OUT/drv" > "$OUT/VERDETTO" 2>&1
VRC=$?
cat "$OUT/VERDETTO"
echo "/dev/vmm dopo: $(ls /dev/vmm 2>/dev/null | tr '\n' ' ')(nessuna distruzione da questo runner)"
exit $VRC
