#!/bin/sh
# run-dedup95-8vp.sh -- Claude 27/10/2026, parere #95 §4.2-4.4 e §5.4-5.5: LIVELLO 2. UNA sessione
# Windows 11 + Hyper-V + WSL2 a 8 VP, braccio A (retry 1, budget 2000, i predefiniti), con la
# traccia di livello 1 (dedup92.d, per tutta la fase) e, durante la compilazione, L2_K finestre
# BREVI di L2_MS ms con le GPA lette dalla scansione (dedup95l2.d via l2-ciclo.sh). COPIA di
# run-dedup92-8vp.sh con queste sole differenze: braccio run-dedup95-8vp-prova.sh; hash e
# compilazione a freddo anche di dedup95l2.d e l2-ciclo.sh; cartella logs/dedup95-8vp-A-<data>.
# Nessuna modifica al kernel. Analisi OFFLINE: dedup92_an.py (livello 1), dedup95l2_an.py --l1
# (livello 2, completezza per finestra, perturbazione dentro/fuori le finestre).
# NON SI LANCIA senza un parere che lo approvi e un NUOVO consenso esplicito dell'utente.
# Uso: sudo -n daemon -f -o <log> sh run-dedup95-8vp.sh   (da root)
MISURA_R=${MISURA_R:-1}
MISURA_BUDGET=${MISURA_BUDGET:-2000}
case "$MISURA_R/$MISURA_BUDGET" in
1/2000) MOD=A;;
*) echo "parere #92: solo il braccio A (MISURA_R=1 MISURA_BUDGET=2000), chiesto $MISURA_R/$MISURA_BUDGET"; exit 4;;
esac
BUDGET_INIZIALE_ATTESO=2000
B=/mnt/linuxulator2/vm/wsl2/linux; N=$B/freebsd-nested/tools/nested
MOD_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9
# parere #93 §2: gli offset della traccia (senza CTF) valgono per QUESTA build: anche il build-id
MOD_BUILDID=d30f6a7f6ea6c9259b5f39604c9399564aba5f49
PROVA=$B/run-dedup95-8vp-prova.sh
PROVA_SHA=71a73914465d42befba3bc6194e06d1692075675d0c7c27ae5c616f9c116d5a5
VM8_SHA=00b620062ecc8ec09671168de7661581b6d0ffccb47abf27812127ad1170bf39
CARICO="kbuild8.sh kbuild-lavoro.sh gapmem.sh gapmon.c memmon.c"
CARICO_SHA=549a0a7db10a848995d9b6a263d5c3008b3fec4e265b50cfca5c276caf003c2e
LAT=$N/dedup92.d
L2=$N/dedup95l2.d
L2_SHA=91cd70d567af621ffb2fe9b0705bccabc80e1845125ccab1611c7c8ee5cd34c6
CICLO_SHA=a9dbc9a1de864fa6276d55e9b68d750ee3ed1544e77ff8e509f1a48e1cea5961
LAT_SHA=ae02d0ffc0a9a75867fcd136331e56865a16cc8bce32d61cbfd3e39bb8625298
[ "$(id -u)" = 0 ] || { echo "va eseguito da root"; exit 4; }
BASE=$B/logs/dedup95-8vp-$MOD-$(date +%Y%m%d-%H%M)
mkdir -p "$BASE" || exit 4
R0="$BASE/riepilogo.txt"
K="vept_keep vept_verify_hpa vept_test_race vept_scan_hold_keep vept_scan_retries nested_shadow_vmcs nested_shadow_verify nested_fast_field_validate nested_shadow_inject nested_vpid_track nested_vpid12_flush vept_scan_budget_us"
PRIMA=$(for k in $K; do sysctl -n hw.vmm.vmx.$k; done | tr '\n' ' ')
{ echo "$K"; echo "$PRIMA"; } > "$BASE/sysctl-iniziali.txt"
RIPRISTINATO=0; RIP_ESITO=NON_ESEGUITO; AVVIATO=0; ESITO=""; PP=""
ripristina() {
	[ $RIPRISTINATO = 1 ] && return 0
	RIPRISTINATO=1
	set -- $PRIMA
	for k in $K; do sysctl hw.vmm.vmx.$k=$1 > /dev/null; shift; done
	ORA=$(for k in $K; do sysctl -n hw.vmm.vmx.$k; done | tr '\n' ' ')
	if [ "$ORA" = "$PRIMA" ]; then RIP_ESITO=OK; else RIP_ESITO=FALLITO; fi
	echo "RIPRISTINO=$RIP_ESITO sysctl ora: $ORA attesi: $PRIMA" | tee -a "$R0"
}
concludi() {	# $1 = segnale (vuoto se nessuno)
	ripristina
	if [ -n "$1" ]; then M=INTERROTTA; case $1 in INT) U=130;; TERM) U=143;; HUP) U=129;; esac
	elif [ $AVVIATO = 0 ]; then M=NON_ESEGUITA; U=4
	else case "$ESITO" in COMPLETA) M=COMPLETA; U=0;; CORRETTEZZA*) M=CORRETTEZZA; U=1;; *) M=INCOMPLETA; U=3;; esac
	fi
	[ "$RIP_ESITO" = OK ] || U=2
	echo "MISURA=$M RIPRISTINO=$RIP_ESITO USCITA=$U ($ESITO)" | tee -a "$R0"
	[ -n "$BASE" ] && [ -d "$BASE" ] && /usr/bin/find "$BASE" -type f -exec chmod a+r {} +
	(cd "$BASE" && /usr/bin/find . -type f ! -name SHA256SUMS -exec sha256 -r {} + > SHA256SUMS)
	trap - EXIT
	exit $U
}
ferma() { echo "STOP: $*" | tee -a "$R0"; concludi; }
segnale() {
	echo "INTERROTTO ($1)" | tee -a "$R0"
	[ -n "$PP" ] && { kill -TERM "$PP" 2>/dev/null; wait "$PP" 2>/dev/null; }
	concludi $1
}
trap 'ripristina' EXIT
trap 'segnale INT' INT
trap 'segnale TERM' TERM
trap 'segnale HUP' HUP
vm_vive() { /bin/ps -ax -o pid= -o comm= -o args= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'; }
vmm_aperti() { for n in /dev/vmm/*; do [ -e "$n" ] || continue; fstat "$n" 2>/dev/null | sed 1d; done; }
# swap: come run-abba-retry-2vp.sh (parere #86 §3)
swap_disp() { swapctl -l | awk 'NR > 1 {print $1}' | sort; }
swap_normalizza() {
	f="$BASE/swap.txt"
	{ echo "== prima $(date +%T)"; swapctl -l; swapinfo -k; } > "$f" 2>&1
	D0=$(swap_disp); [ -n "$D0" ] || { SWAPERR="nessun dispositivo di swap"; return 1; }
	u=$(swapinfo -k | awk 'NR > 1 {s += $3} END {print s + 0}')
	if [ "$u" -eq 0 ]; then echo "swap gia' vuoto: nessun ciclo" >> "$f"; else
		pg=$(sysctl -n hw.pagesize)
		disp=$(( ( $(sysctl -n vm.stats.vm.v_free_count) + $(sysctl -n vm.stats.vm.v_inactive_count) ) * pg / 1024 ))
		echo "swap usato ${u} KB, memoria disponibile ${disp} KB" >> "$f"
		[ "$disp" -ge $(( u * 2 )) ] || { SWAPERR="memoria disponibile ${disp} KB < 2 x swap usato ${u} KB"; return 1; }
		if ! swapoff -a >> "$f" 2>&1; then
			for d in $D0; do swapctl -l | awk '{print $1}' | /usr/bin/grep -qx "$d" || swapon "$d" >> "$f" 2>&1; done
			SWAPERR="swapoff fallito"; return 1
		fi
		for d in $D0; do swapon "$d" >> "$f" 2>&1; done
		sleep 30
	fi
	D1=$(swap_disp)
	{ echo "== dopo $(date +%T)"; swapctl -l; swapinfo -k; } >> "$f" 2>&1
	[ "$D1" = "$D0" ] || { SWAPERR="dispositivi di swap diversi"; return 1; }
}

echo "=== controlli a freddo ===" | tee -a "$R0"
[ "$(sha256 -q /boot/kernel/vmm-restore.ko)" = "$MOD_SHA" ] || ferma "modulo diverso da 27125f004917"
readelf -n /boot/kernel/vmm-restore.ko 2>/dev/null | /usr/bin/grep -q "Build ID: $MOD_BUILDID" || ferma "build-id del modulo diverso da $MOD_BUILDID (offset della traccia non validi)"
[ "$(sha256 -q $PROVA)" = "$PROVA_SHA" ] || ferma "run-dedup95-8vp-prova.sh diverso da quello rivisto"
[ "$(sha256 -q $N/12-Windows-11-vm12-senza-gpu-8vp)" = "$VM8_SHA" ] || ferma "script della VM a 8 VP diverso"
[ "$(sha256 -q $LAT)" = "$LAT_SHA" ] || ferma "dedup92.d diversa"
[ "$(sha256 -q $L2)" = "$L2_SHA" ] || ferma "dedup95l2.d diversa"
[ "$(sha256 -q $N/l2-ciclo.sh)" = "$CICLO_SHA" ] || ferma "l2-ciclo.sh diverso"
[ "$( (cd $B/faseA && sha256 -r $CARICO) | sha256 -q)" = "$CARICO_SHA" ] || ferma "file del carico diversi"
sysctl -n hw.vmm.vmx.nested_invept_opt >/dev/null 2>&1 && ferma "esiste un interruttore di elisione: build inattesa"
kldstat | /usr/bin/grep -q hwpmc && ferma "hwpmc caricato: non previsto in questa misura"
[ "$(sysctl -n hw.vmm.vmx.vept_scan_budget_us)" = "$BUDGET_INIZIALE_ATTESO" ] || ferma "vept_scan_budget_us iniziale diverso da $BUDGET_INIZIALE_ATTESO (stato non standard)"
# disco della VM (dopo il reset del 27/10 era rimasto non pulito): montato in scrittura, immagine presente
mount -p | awk '$1 == "/dev/da0p2" && $2 == "/mnt/da0p2" && $4 ~ /rw/ {ok = 1} END {exit !ok}' || ferma "/dev/da0p2 non montato in scrittura su /mnt/da0p2 (fsck?)"
[ -s /mnt/da0p2/bhyve/img/Windows/11/Windows11.img ] || ferma "Windows11.img assente"
dtrace -e -s $LAT 1 > "$BASE/lat-compila.txt" 2>&1 || ferma "dedup92.d non compila sul modulo installato"
dtrace -e -s $L2 1 100 > "$BASE/l2-compila.txt" 2>&1 || ferma "dedup95l2.d non compila sul modulo installato"
[ "$(sysctl -n hw.vmm.vmx.vept_diag)" = 0 ] || ferma "vept_diag acceso: cambierebbe il gestore"
LIBERI=$(df -k $B/logs | awk 'NR == 2 {print $4 + 0}')
[ "${LIBERI:-0}" -ge 2097152 ] || ferma "meno di 2 GiB liberi in logs/ ($LIBERI KB)"
v=$(vm_vive); [ -n "$v" ] && { echo "$v" | tee -a "$R0"; ferma "processo VM vivo (la vm0:12 dell'utente o altro)"; }
v=$(vmm_aperti); [ -n "$v" ] && ferma "nodo /dev/vmm aperto"
{
	echo "modulo $MOD_SHA build-id $MOD_BUILDID"; echo "prova $PROVA_SHA"; echo "traccia $LAT_SHA livello 2 $L2_SHA ciclo $CICLO_SHA"; echo "vm 8 VP $VM8_SHA"; echo "carico $CARICO_SHA"
	(cd $B/faseA && sha256 -r $CARICO); echo "involucro $(sha256 -q $0)"; echo "sysctl iniziali: $PRIMA"
	cpucontrol -m 0x8b /dev/cpuctl6; cpucontrol -i 0x1 /dev/cpuctl6
	sysctl kern.osrelease hw.ncpu hw.vmm.vmx.vept_scan_budget_us; swapinfo -h
	echo "braccio $MOD: vept_scan_retries=$MISURA_R, vept_scan_budget_us=$MISURA_BUDGET"; mount -p | grep da0p2; ls -la /mnt/da0p2/bhyve/img/Windows/11/
} > "$BASE/baseline.txt" 2>&1
swap_normalizza || ferma "normalizzazione dello swap: $SWAPERR"

O=$BASE/1-$MOD
mkdir -p "$O"
# budget del braccio: scritto PRIMA dell'avvio e riletto (il braccio non lo tocca)
sysctl hw.vmm.vmx.vept_scan_budget_us=$MISURA_BUDGET > /dev/null 2>&1
[ "$(sysctl -n hw.vmm.vmx.vept_scan_budget_us)" = "$MISURA_BUDGET" ] || ferma "vept_scan_budget_us=$MISURA_BUDGET non applicato"
echo "######## misura a 8 VP, braccio $MOD (vept_scan_retries=$MISURA_R, budget $(sysctl -n hw.vmm.vmx.vept_scan_budget_us) us riletto) $(date +%T)" | tee -a "$R0"
AVVIATO=1
env O="$O" MOD=$MOD R=$MISURA_R sh "$PROVA" 480 2 > "$O/run.out" 2>&1 &
PP=$!; wait $PP; PP=
ESITO=$(/usr/bin/sed -n 's/^OUTPUT [^ ]* //p' "$O/run.out" | tail -1)
echo "   esito del braccio: ${ESITO:-SENZA_ESITO} ($(date +%T))" | tee -a "$R0"
/usr/bin/grep -E "CHECKPOINT|^real|kernel rc|ext4:|LAVORO-FINE|AZIONI_CC" "$O/run.out" | sed 's/^/   /' | tee -a "$R0"
concludi
