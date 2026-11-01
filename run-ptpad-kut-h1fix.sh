#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-ptpad-kut-h1fix.sh.non-conforme
echo "INERTE: run-ptpad-kut-h1fix.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-ptpad-kut-h1fix.sh.non-conforme" >&2; exit 4
# run-ptpad-kut-h1fix.sh -- Claude 28/10/2026, parere #111 §5: runner della SOLA sessione KUT col modulo
# della correzione di H1 (r110, d0465140). Derivato da run-ptpad-kut.sh (che resta per il modulo originale).
# Richiede che il modulo nuovo sia GIA' caricato da caldo/modulo-caldo.sh --esegui originale r110 (consenso separato); qui il
# piano e' SOLO B,C,H,A,H_D,A_D, nessun caso D, nessun --esegui-d. Dopo la sessione: caldo/modulo-caldo.sh
# --esegui r110 originale. Uscita 6 = modulo nuovo non caricato (in --prova: controlli fatti, nessuna VM).
# --- testo originale ---
# run-ptpad-kut.sh -- Claude 27/10/2026, pareri #101, #106, #107. Runner del test deterministico
# AUDIT-PTP-HOLD sotto QEMU `-accel bhyve` (lo stesso percorso di kut-run.sh e della campagna
# b1race: VM "vm2", UNA vCPU, cpuset sulla CPU 6). MAI la vm0:12 Windows. Nessuna patch, nessun
# sysctl scritto (solo letture).
#
#   run-ptpad-kut.sh --prova  <piano> <out>   preflight a freddo + comando: NESSUNA VM
#   run-ptpad-kut.sh --esegui <piano> <out>   SOLO dopo consenso esplicito: sessione SENZA casi D
#   run-ptpad-kut.sh --esegui-d <piano> <out> SOLO dopo consenso SEPARATO: sessione con UN caso D
#
# Il piano lo esegue L1 (parere #106 D1): la .flat legge il piano dalla COM1 e lo ripete; senza
# questo runner non esegue alcun caso. Il driver (ptpad-drive.py) fa l'handshake per caso, fotografa
# il contatore a L1 fermo, apre la traccia FBT prima di QEMU, e su "Error running vm" chiude il
# caso con TERM bhyve_died e uccide QEMU (D3: QEMU non muore da solo, rientra in vm_run).
# Nessun riavvio, nessuna corsa successiva automatica: un D per avvio, l'altro resta NOT_RUN.
# Parere #107: il driver NON manda l'ACK al caso successivo se il caso appena chiuso non e' pulito
# (cancello B; delta != 1; esito non ARCH_PASS/H1). COM1 su un chardev stdio ESPLICITO e non
# multiplexato, niente monitor. Il preflight collauda la traccia DTrace sull'host (senza VM).
# USCITA: 0 sessione eseguita e analizzata senza TEST_ERROR; 3 analisi con TEST_ERROR;
#         2 STOP del driver; 4 STOP al preflight (nessuna VM); 5 VM ancora viva o nodo rimasto.
set -u
B=/mnt/linuxulator2/vm/wsl2/linux
N=$B/freebsd-nested/tools/nested
MOD=$B/obj-h1-ptphold-r110/mnt/linuxulator2/vm/wsl2/linux/freebsd-h1-ptphold/amd64.amd64/sys/modules/vmm/vmm-restore.ko
MOD_SHA=d0465140490570335c295ee1c7d1584cf95a65aafaa0397b79bd78422ab86873	# r110, diff fd8ffd09
MOD_ORIG_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9	# /boot: NON deve essere caricato
FLAT_RITIRATA=8d10c1f5d79cad3065c962fafc95e42c52c582a6f39507804699ab9061092bc1	# #104: eseguiva sempre i D
MOD_BUILDID=1ba0803c8165661c9e6b0a2c0c73c32182998341
# sessione 1 (27/10): la .flat p106 (0b723262) faceva SKIP prima del piano (D su pagina GRANDE)
# sessione 1b (27/10): la s1fix (77025a6b) azzerava D, ma l'IOAPIC a 8 byte legge 0: dwr cieco -> sentinella
# sessione 1c (27/10): la s1b (1181e2cb) ha riprodotto H1 in A/A_D ma senza il controllo hardware H
# 28/10 (#111 §5.5): .flat con la riga XINFO (GLA e RIP dal VMCS12); codice di L2 identico alla 1d
FLAT=$B/logs/ptpad-build-freebsd-20261028-xinfo/vmx-ptpad.flat
FLAT_SHA=412ee7e423acba46fc10bb918120d23cb0028b109ddf0964f34d568920f367ed
DRV=$N/ptpad-drive.py;	DRV_SHA=b214b3ce697e10ad6c144aae41fbb9fe6a3011d39c741d2beafb79f0bdf65a2a
FBT=$N/ptpad-fbt.d;	FBT_SHA=3e5f76d18024467d03e84bc0028fd17bc6dbd776439730fcae5154641c584d9a
FBC=$N/ptpad-fbt-collaudo.sh;	FBC_SHA=1288acdbc41599d0bfca363f6798f7149f5995f2fc63aa7c44d49622fa365994
AN=$B/ptpad_an.py;	AN_SHA=47be494957f41a22404ceb2d9f2db9eb8cff7f6b4bccf2e4af7c3a00d8f4a9a2
QEMU=$B/stage/current/bin/qemu-system-x86_64
PCBIOS=$B/qemu-nested/pc-bios
PY=/usr/local/bin/python3
VMPAT='[b]hyve|[q]emu-system'

[ $# -eq 3 ] || { echo "uso: $0 --prova|--esegui B,C,H,A,H_D,A_D <out>"; exit 4; }
MODO=$1; PIANO=$2; OUT=$3
ferma() { echo "STOP: $*"; exit 4; }
# #111 §5.3: UN solo piano ammesso, niente casi D, niente --esegui-d
[ "$PIANO" = "B,C,H,A,H_D,A_D" ] || ferma "piano '$PIANO' rifiutato: ammesso solo B,C,H,A,H_D,A_D"
[ "$MODO" = --esegui-d ] && ferma "--esegui-d non esiste in questo runner (casi D esclusi dal piano H1)"
case "$PIANO" in
*D_DATA*|*D_PTP*) [ "$MODO" = --esegui ] && ferma "il piano ha un caso D: serve --esegui-d (consenso separato)"; TMO=60;;
*) [ "$MODO" = --esegui-d ] && ferma "--esegui-d senza caso D nel piano"; TMO=120;;
esac
case "$MODO" in --prova|--esegui|--esegui-d) ;; *) ferma "modo $MODO";; esac
[ -e "$OUT" ] && ferma "$OUT esiste gia': nessuna sovrascrittura"

vm_vive() { /bin/ps -ax -o pid= -o comm= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'; }	# solo il NOME: la riga di comando di altri processi puo' contenere "bhyve"
vmm_aperti() { for v in /dev/vmm/*; do [ -e "$v" ] || continue; sudo -n /usr/bin/fstat "$v" 2>/dev/null | /usr/bin/sed 1d; done; }

echo "=== preflight a freddo (sola lettura) ==="
[ "$(sha256 -q $MOD)" = "$MOD_SHA" ] || ferma "modulo di staging diverso da d0465140"
readelf -n $MOD 2>/dev/null | grep -q "Build ID: $MOD_BUILDID" || ferma "build-id del modulo di staging diverso"
kldstat -n vmm-restore.ko >/dev/null 2>&1 || ferma "vmm-restore.ko non caricato"
CAR=$(/sbin/kldstat -v -n vmm-restore.ko 2>/dev/null | sed -n 's/.*vmm-restore\.ko (\(.*\))$/\1/p' | head -1)
NONCAR=""
if [ "$CAR" != "$MOD" ] || [ "$(sha256 -q "$CAR")" != "$MOD_SHA" ] || ! /sbin/sysctl -n hw.vmm.vmx.nested_ept12_viol_emul_reflected >/dev/null 2>&1; then
	[ "$MODO" = --prova ] || { echo "STOP: caricato $CAR, non il modulo r110 (prima: sh $B/caldo/modulo-caldo.sh --esegui originale r110)"; exit 6; }
	NONCAR="caricato $CAR ($(sha256 -q "$CAR")): il modulo r110 NON e' caricato"
fi
strings "$FLAT" | grep -q 'PTPAD XINFO' || ferma "la .flat non stampa XINFO (#111 §5.5)"
[ "$FLAT_SHA" != "$FLAT_RITIRATA" ] || ferma "configurazione che punta alla .flat RITIRATA"
[ "$(sha256 -q $FLAT)" != "$FLAT_RITIRATA" ] || ferma "la .flat e' quella RITIRATA (8d10c1f5)"
[ "$(sha256 -q $FLAT)" = "$FLAT_SHA" ] || ferma ".flat diversa da quella congelata (parere #106)"
strings "$FLAT" | grep -q 'PTPAD WAIT piano' || ferma "la .flat non ha l'handshake del parere #106"
case "$PIANO" in *H*) strings "$FLAT" | grep -q 'pteaddr=' || ferma "piano con casi H ma la .flat non stampa pteaddr";; esac
[ "$(sha256 -q $DRV)" = "$DRV_SHA" ] || ferma "ptpad-drive.py diverso da quello collaudato"
[ "$(sha256 -q $FBT)" = "$FBT_SHA" ] || ferma "ptpad-fbt.d diverso da quello collaudato"
[ "$(sha256 -q $AN)" = "$AN_SHA" ] || ferma "ptpad_an.py diverso da quello collaudato"
[ "$(sha256 -q $FBC)" = "$FBC_SHA" ] || ferma "ptpad-fbt-collaudo.sh diverso da quello collaudato"
[ -x "$QEMU" ] || ferma "manca $QEMU"
strings "$QEMU" | grep -q 'Error running vm' || ferma "QEMU senza il messaggio d'errore atteso dal driver"
v=$(vm_vive); [ -n "$v" ] && { echo "$v"; ferma "una VM e' gia' viva"; }
v=$(vmm_aperti); [ -n "$v" ] && { echo "$v"; ferma "un nodo /dev/vmm e' aperto"; }
# vm2 presente e NON aperto e' normale: QEMU lo distrugge e lo ricrea all'avvio
# (qemu-nested/accel/bhyve/bhyve-all.c:3654-3661); i nodi aperti li ha gia' esclusi vmm_aperti
NODI0=$(ls /dev/vmm 2>/dev/null | grep -vx vm2 | tr '\n' ' ')
sudo -n /usr/sbin/dtrace -e -s $FBT 1 >/dev/null 2>&1 || ferma "ptpad-fbt.d non compila sul modulo caricato"
mkdir -p "$OUT" || ferma "mkdir $OUT"
sh $N/test-ptpad.sh "$OUT/collaudo" > "$OUT/collaudo.txt" 2>&1 || ferma "collaudo offline dell'oracolo e del driver fallito ($OUT/collaudo.txt)"
sh $FBC "$OUT/collaudo-fbt" > "$OUT/collaudo-fbt.txt" 2>&1 || ferma "collaudo DTrace sull'host fallito ($OUT/collaudo-fbt.txt)"
echo "preflight OK: modulo $MOD_SHA, flat $FLAT_SHA, collaudo $(grep -c '^  ok' $OUT/collaudo.txt) ok, DTrace $(grep -c '^  ok' $OUT/collaudo-fbt.txt) ok"

# #107 §2: COM1 su chardev stdio ESPLICITO, non multiplexato, senza segnali; nessun monitor
VMCMD="/usr/bin/cpuset -l 6 /usr/bin/timeout -k 1s $((TMO + 30))s $QEMU -L $PCBIOS --no-reboot -nodefaults \
-accel bhyve,nested=on -device pc-testdev -device isa-debug-exit,iobase=0xf4,iosize=0x4 -display none \
-monitor none -chardev stdio,id=ptpad,mux=off,signal=off -serial chardev:ptpad \
-device pci-testdev -smp 1 -m 256 -cpu max -kernel $FLAT -append vmx_ptpad_fidelity_test"
# #107 §5.3: controllo STATICO della riga effettiva
for x in ' -accel bhyve,nested=on ' ' -smp 1 ' ' -monitor none ' 'stdio,id=ptpad,mux=off,signal=off' \
    ' -serial chardev:ptpad ' " -kernel $FLAT " ' -append vmx_ptpad_fidelity_test'; do
	case "$VMCMD" in *"$x"*) ;; *) ferma "riga QEMU senza '$x'";; esac
done
for x in 'mon:stdio' '-nographic' 'mux=on' '-serial stdio' 'vm0' '-daemonize'; do
	case "$VMCMD" in *"$x"*) ferma "riga QEMU con '$x'";; esac
done
[ "$(echo "$VMCMD" | grep -o -- '-serial' | wc -l | tr -d ' ')" = 1 ] || ferma "piu' di una -serial"
{
	echo "piano $PIANO modo $MODO timeout $TMO"
	echo "modulo $MOD_SHA build-id $MOD_BUILDID"
	echo "flat $FLAT_SHA driver $DRV_SHA fbt $FBT_SHA collaudo-fbt $FBC_SHA oracolo $AN_SHA script $(sha256 -q $0)"
	echo "flat ritirata (rifiutata): $FLAT_RITIRATA"
	echo "vm: $VMCMD"
	echo "nodi /dev/vmm: $(ls /dev/vmm 2>/dev/null | tr '\n' ' ')"
	/sbin/sysctl hw.vmm.vmx.nested_ept_mmio_emulated hw.vmm.vmx.nested_ept12_viol_reflected kern.osrelease
	/sbin/sysctl hw.vmm.vmx.nested_ept12_viol_emul_reflected hw.vmm.vmx.nested_ept12_viol_emul_stale \
	    hw.vmm.vmx.nested_ept12_viol_emul_nocache hw.vmm.vmx.vept_ptp_write_retry_xlate \
	    hw.vmm.vmx.vept_ptp_write_retry_remap 2>&1
	echo "modulo caricato: $CAR $(sha256 -q "$CAR")"
	/usr/sbin/pciconf -l | grep '^ppt'
} > "$OUT/manifest.txt"
if [ "$MODO" = --prova ]; then
	cat "$OUT/manifest.txt"
	[ -n "$NONCAR" ] && echo "PROVA: $NONCAR"
	echo "PROVA: nessuna VM avviata. Il comando del driver sarebbe:"
	echo "  sudo -n $PY $DRV --piano $PIANO --out $OUT/drv --fbt $FBT --oracolo $AN --timeout $TMO -- $VMCMD"
	[ -n "$NONCAR" ] && exit 6
	exit 0
fi

echo "=== sessione $PIANO: avvio (UNA VM, vm2) ==="
sudo -n $PY $DRV --piano "$PIANO" --out "$OUT/drv" --fbt $FBT --oracolo $AN --timeout $TMO -- $VMCMD | tee "$OUT/driver.out"
i=0; vivo=""
until [ -z "$(vm_vive)" ] && [ -z "$(vmm_aperti)" ]; do
	i=$((i + 1)); [ $i -gt 150 ] && { vivo=1; break; }; sleep 0.2
done
echo "nodi /dev/vmm dopo: $(ls /dev/vmm 2>/dev/null | tr '\n' ' ')" | tee -a "$OUT/manifest.txt"
$PY $AN "$OUT/drv/combinato.txt" > "$OUT/verdetto.txt" 2>&1; an=$?
cat "$OUT/verdetto.txt"
(cd "$OUT" && sha256 -r manifest.txt driver.out verdetto.txt drv/* > SHA256SUMS 2>/dev/null)
[ -n "$vivo" ] && { echo "ATTENZIONE: VM ancora viva o nodo aperto dopo 30 s"; exit 5; }
[ "$(ls /dev/vmm 2>/dev/null | grep -vx vm2 | tr '\n' ' ')" = "$NODI0" ] || { echo "ATTENZIONE: nodi /dev/vmm cambiati oltre vm2"; exit 5; }
grep -q 'USCITA=2' "$OUT/driver.out" && exit 2
echo "PROSSIMO PASSO OBBLIGATORIO: sh $B/caldo/modulo-caldo.sh --esegui r110 originale (ritorno al modulo originale)"
[ $an = 0 ] && exit 0 || exit 3
