#!/bin/sh
# run-p3-kut.sh -- Claude 01/11/2026. UNA sessione del test di PROVOCAZIONE di P3 sullo STADIO 11 (decisione dell'utente
# del 01/11: «preparalo»). Stesso schema e stessi strumenti del runner KUT (run-opnd-kut.sh): produttore del manifest
# opnd-manifest.sh (vm2), guardia_azione su ogni azione, sonde in un .d approvato, arresto di dtrace con om_ferma_dtrace,
# sigillo. Differenze: la .flat e' p3_contesa (kut-src-p3, logs/kut-p3-build-1); DUE vCPU (-smp 2) su DUE CPU
# dell'host (cpuset -l 6,7: con una sola CPU fisica lo scrittore non girerebbe MAI durante il walk di L0, e la contesa
# non si produrrebbe); hw.vmm.gla2gpa_restart_capped letto prima e dopo; verdetto p3-verdetto.py.
# SOLO lo stadio 11: sullo stadio 10 lo stesso test terrebbe il thread del vCPU nel kernel per tutta la contesa (P3).
#   sh run-p3-kut.sh --prova|--esegui <cartella nuova in logs/> [stadio11]
# Uscite: quella del verdetto (0 PASS, 1 FAIL, 5 INCONCLUSIVO); 4 STOP ai controlli; 6 modulo non caricato (--prova) o
# operatore; 7 DTrace non attivata; 5 anche per sessione non valida; 8 sessione incompleta.
set -u
B=/mnt/linuxulator2/vm/nested-work
for v in FS SM_FINTO VR_FINTO OM_FINTO SM_DIARIO; do eval "x=\${$v:-}"; [ -z "$x" ] || { echo "STOP: variabile di collaudo $v nell'ambiente"; exit 4; }; done
. /mnt/linuxulator2/vm/nested-work/caldo/guardia.sh
guardia_azione || { echo "STOP: guardia: nessuna sessione"; exit 4; }
MOD=$B/logs/stadio11-congelato-20261101/vmm-restore.ko
MOD_SHA=3bfc6ae8b8c938f131d428cc353dafcad4e99169fbe45cd6a288f9e7e70d4a43
MOD_BUILDID=7947f8af2c30b6a1e051ff067d265fe433490b83
OIDS="hw.vmm.vmx.nested_ept12_viol_emul_reflected hw.vmm.vmx.vept_h2_viol_final hw.vmm.gla2gpa_restart_capped hw.vmm.fatal_latches hw.vmm.vmx.nested_operand_fatal"
OID_ATTESO=11111
FLAT=$B/logs/kut-p3-build-2/x86/p3_contesa.flat	# v2: contatore nei bit ignorati (la v1, due valori, non produceva la contesa: ABA)
FLAT_SHA=1519e4017b0f320d50b3705efea67883c5632c9679ebf1abd44c2dfbc10e6cec
DRV=$B/kut-drive.py
DRV_SHA=dee6b45caa10c04f8b7d95235894c5718d8f72da1434fdd91577a20ac84c7323
VER=$B/p3-verdetto.py
OM=$B/opnd-manifest.sh
QEMU=$B/build-qemu-gate-nested-sr/qemu-system-x86_64
QEMU_SHA=650a2bdec6f0fb61ec19066dcd13edd0b647267fd0cec2d0ce8974124b08859a
LIBV_ATTESA=/usr/lib/libvmmapi.so.7
LIBV_SHA=116a74309070a59eb571a8ae44411b482baa148f8398032211a129053bb7c14e
LOADER_SHA=4f3d0c57da4372da8cb501096aa45c359edebf7c11e061c8996e314898022230
PCBIOS=$B/qemu-nested/pc-bios
MACCHINA=pc-i440fx-10.2
PY=/usr/local/bin/python3
LIMITE_BLOCCHI=2097152
SONDE_D=$B/installazione/files/usr/local/libexec/claude-vmm/sonde-wsl-v1.d	# le sole sonde del latch e dell'ombra
SONDE_D_SHA=ed213031b8bd4531d42e02c205b7815ff28aee299c6e4ec9969db5377a241fc1
SONDE_ET=sonde-wsl-v1
TMO=120
ferma() { echo "STOP: $*"; exit 4; }
[ $# = 2 ] || [ $# = 3 ] || { echo "uso: $0 --prova|--esegui <cartella nuova in logs/> [stadio11]"; exit 4; }
MODO=$1; OUT=$2; STADIO=${3:-stadio11}
case "$MODO" in --prova|--esegui) ;; *) ferma "modo $MODO";; esac
[ "$STADIO" = stadio11 ] || ferma "il test di provocazione di P3 gira SOLO sullo stadio 11, non su '$STADIO'"
case "$OUT" in /mnt/linuxulator2/vm/nested-work/logs/*) ;; *) ferma "uscita fuori da nested-work/logs: $OUT";; esac
[ -e "$OUT" ] && ferma "$OUT esiste gia': nessuna sovrascrittura"
[ "$(df -T "$(dirname "$OUT")" | awk 'NR==2{print $2}')" = zfs ] || ferma "uscita non su ZFS"
ulimit -f $LIMITE_BLOCCHI

echo "=== preflight (sola lettura) ==="
[ "$(sha256 -q "$MOD")" = "$MOD_SHA" ] || ferma "copia congelata diversa dallo stadio 11"
readelf -n "$MOD" 2>/dev/null | grep -q "Build ID: $MOD_BUILDID" || ferma "build-id della copia congelata diverso"
for x in sdt_vmm_vmx_nested_opndfatal sdt_vmm_vmx_nested_veptunemul; do nm "$MOD" | grep -q " $x\$" || ferma "sonda $x assente dal modulo"; done
nm "$MOD" | grep -Eq " [tT] vmx_shvmcs_enter\$" || ferma "vmx_shvmcs_enter assente dal modulo"
CAR=$(/sbin/kldstat -v -n vmm-restore.ko 2>/dev/null | sed -n 's/.*vmm-restore\.ko (\(.*\))$/\1/p' | head -1)
sig=""; for o in $OIDS; do sig=$sig$(/sbin/sysctl -n $o >/dev/null 2>&1 && echo 1 || echo 0); done
NONCAR=""
if [ "$CAR" != "$MOD" ] || [ "$sig" != "$OID_ATTESO" ]; then
	[ "$MODO" = --prova ] || { echo "STOP: caricato '$CAR' (oid $sig), non lo stadio 11 (oid $OID_ATTESO)"; exit 6; }
	NONCAR="caricato '$CAR' (oid $sig): lo stadio 11 NON e' caricato (lo scambio e' un passo separato)"
fi
[ "$(sha256 -q /boot/loader.conf)" = "$LOADER_SHA" ] || ferma "loader.conf cambiato"
[ "$(sha256 -q "$FLAT")" = "$FLAT_SHA" ] || ferma "p3_contesa.flat diversa da quella costruita"
for x in 'P3 pte' 'P3 riferimento cicli' 'P3 round'; do strings "$FLAT" | grep -q "$x" || ferma "la .flat non stampa '$x'"; done
[ "$(sha256 -q "$SONDE_D")" = "$SONDE_D_SHA" ] || ferma "programma D $SONDE_D diverso da quello approvato"
grep -q "DTRACE_ATTIVO $SONDE_ET" "$SONDE_D" || ferma "il programma D non stampa l'etichetta $SONDE_ET"
[ "$(sha256 -q "$DRV")" = "$DRV_SHA" ] || ferma "kut-drive.py diverso da quello congelato"
[ -r "$VER" ] && [ -r "$OM" ] || ferma "strumenti mancanti"
. "$OM"
[ "$(sha256 -q "$QEMU")" = "$QEMU_SHA" ] || ferma "QEMU diversa da quella protetta"
strings "$QEMU" | grep -q 'porta della VM chiusa dal vCPU' || ferma "QEMU senza la porta della VM"
[ "$(/sbin/sysctl -n hw.vmm.vmx.nested_shadow_vmcs 2>/dev/null)" = 0 ] || [ -n "$NONCAR" ] || ferma "hw.vmm.vmx.nested_shadow_vmcs != 0"
LIBV=$(guardia_azione && sudo -n /usr/bin/ldd "$QEMU" | awk '/libvmmapi/{print $3}')
[ "$LIBV" = "$LIBV_ATTESA" ] && [ "$(sha256 -q "$LIBV")" = "$LIBV_SHA" ] || ferma "libvmmapi $LIBV diversa da quella attesa"
v=$(/bin/ps -ax -o pid= -o comm= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'); [ -n "$v" ] && { echo "$v"; ferma "una VM e' gia' viva"; }
[ -z "$(ls /dev/vmm 2>/dev/null)" ] || ferma "/dev/vmm non vuoto ($(ls /dev/vmm | tr '\n' ' ')): nessuna distruzione implicita"
kldstat -q -n amdgpu.ko && ferma "amdgpu caricato"
[ "$(sysctl -n hw.ncpu)" -ge 8 ] || ferma "servono le CPU 6 e 7 dell'host"

VMCMD="/usr/bin/cpuset -l 6,7 /usr/bin/timeout -k 1s $((TMO + 30))s $QEMU -L $PCBIOS --no-reboot -nodefaults \
-machine $MACCHINA -accel bhyve,nested=on -device isa-debug-exit,iobase=0xf4,iosize=0x4 -display none -monitor none \
-chardev stdio,id=p3,mux=off,signal=off -serial chardev:p3 -smp 2 -m 256 -cpu max -kernel $FLAT"
case "$VMCMD" in *mon:stdio*|*-daemonize*|*vm0*) ferma "riga QEMU non ammessa";; esac
DRVCMD="$PY $DRV --out $OUT/drv --timeout $TMO -- $VMCMD"
echo "preflight OK: stadio 11 $MOD_SHA ($MOD_BUILDID), flat $FLAT_SHA, QEMU $QEMU_SHA, libvmmapi $LIBV_SHA, sonde $SONDE_D_SHA"
[ -n "$NONCAR" ] && echo "PROVA: $NONCAR"
echo "comando: sudo -n $DRVCMD"
[ "$MODO" = --prova ] && { echo "PROVA: nessuna VM avviata"; [ -n "$NONCAR" ] && exit 6; exit 0; }

mkdir -p "$OUT" || ferma "mkdir $OUT"
PIANO=p3; VER_SHA=$(sha256 -q "$VER"); QEMU_VER=$("$QEMU" --version | head -1); OM_SCRIPT_SHA=$(sha256 -q "$0")
om_apri "$OUT" || { om_non_avviata "apertura non riuscita: $OM_ERR" || echo "ATTENZIONE: sigillo fallito"; echo "STOP: $(tail -3 "$OUT/manifest.txt" | tr '\n' ' ')"; exit 4; }
om_riga "sonde $SONDE_D $SONDE_D_SHA etichetta $SONDE_ET"
om_riga "stadio $STADIO firma oid $OID_ATTESO"
p3_leggi() { /sbin/sysctl -n hw.vmm.gla2gpa_restart_capped 2>/dev/null || echo illeggibile; }
P3_PRIMA=$(p3_leggi); P3_MAX=$(/sbin/sysctl -n hw.vmm.gla2gpa_restart_max 2>/dev/null || echo -)
om_riga "p3 prima: gla2gpa_restart_capped=$P3_PRIMA gla2gpa_restart_max=$P3_MAX"
guardia_azione || ferma "guardia"; sudo -n /usr/sbin/dtrace -s "$SONDE_D" $((TMO + 60)) > "$OUT/sonde.txt" 2> "$OUT/sonde-err.txt" &
DT=$!
i=0; while [ $i -lt 15 ] && ! grep -q DTRACE_ATTIVO "$OUT/sonde.txt" 2>/dev/null; do sleep 1; i=$((i + 1)); done
if ! grep -q DTRACE_ATTIVO "$OUT/sonde.txt" 2>/dev/null; then
	if ! om_ferma_dtrace $DT 30; then
		echo "sessione: NON CHIUSA: dtrace ancora attivo dopo SIGKILL (operatore)" >> "$OUT/manifest.txt"
		echo "OPERATORE: dtrace della sessione ancora vivo: nessuna finalizzazione, nessuna VM avviata"; exit 6
	fi
	om_non_avviata "DTrace non attivata in 15 s" || echo "ATTENZIONE: sigillo fallito"
	echo "STOP: DTrace non attivata in 15 s ($(cat "$OUT/sonde-err.txt")): nessuna VM avviata"; exit 7
fi
guardia_azione && eval sudo -n $DRVCMD > "$OUT/driver.out" 2>&1
DRC=$?
cat "$OUT/driver.out"
sleep 1
if ! om_ferma_dtrace $DT 30; then
	echo "sessione: NON CHIUSA: dtrace ancora attivo dopo SIGKILL (operatore)" >> "$OUT/manifest.txt"
	echo "OPERATORE: dtrace della sessione ancora vivo: nessuna finalizzazione (uscita 6)"; exit 6
fi
FIN=""
P3_DOPO=$(p3_leggi)
om_riga "p3 dopo: gla2gpa_restart_capped=$P3_DOPO"
echo "gla2gpa_restart_capped $P3_PRIMA $P3_DOPO" > "$OUT/contatori-p3.txt"
om_chiudi || FIN="${FIN:+$FIN; }chiusura INCOMPLETA: $OM_ERR"
grep -E '^(contatori dopo|p3 (prima|dopo)|vm2 dopo|ATTENZIONE)' "$OUT/manifest.txt"
echo "driver: uscita $DRC (0 = sessione valida)"
$PY "$VER" "$OUT" > "$OUT/VERDETTO" 2>&1
VRC=$?
cat "$OUT/VERDETTO"
om_sigilla || FIN="${FIN:+$FIN; }sigillo non riuscito"
echo "/dev/vmm dopo: $(ls /dev/vmm 2>/dev/null | tr '\n' ' ')(nessuna distruzione da questo runner)"
[ -n "$FIN" ] && { echo "sessione INCOMPLETA ($FIN): uscita 8 (verdetto $VRC)"; exit 8; }
[ $OM_VM2_ESTRANEA = 1 ] && { echo "sessione NON valida: vm2 non e' l'istanza della sessione (uscita 5)"; exit 5; }
[ $OM_DT_FORZATO = 1 ] && { echo "sessione NON valida: dtrace fermato con SIGKILL (uscita 5)"; exit 5; }
[ $OM_RICARICATO = 1 ] && { echo "sessione NON valida: il modulo non e' l'istanza dell'apertura (uscita 5)"; exit 5; }
exit $VRC
