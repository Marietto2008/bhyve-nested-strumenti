#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-abba-retry-2vp.sh.non-conforme
echo "INERTE: run-abba-retry-2vp.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-abba-retry-2vp.sh.non-conforme" >&2; exit 4
# run-abba-retry-2vp.sh -- Claude 27/10/2026, parere #85 §3: ABBA a 2 VP su
# Windows 11 + Hyper-V + WSL2 (vm0:12), ordine A1 B1 B2 A2 con
# vept_scan_retries 1 2 2 1 come UNICA variabile (run-abba-retry-prova.sh fissa
# e rilegge tutto il resto). Modulo 27125f004917, niente elisione INVEPT,
# niente modo B. Un braccio alla volta, nessun retry automatico.
# Prima di ogni braccio: nessuna VM viva (bhyve/QEMU per riga di comando,
# nodi /dev/vmm aperti), swap dell'host svuotato (contaminazione del 25/10).
# Stop della campagna: CORRETTEZZA (shadow, mismatch HPA, VPID02 spento,
# errori sha256), braccio INCOMPLETO o CONFIG, isolamento violato.
# Ripristino idempotente e verificato dei sysctl INIZIALI (EXIT/INT/TERM/HUP;
# non SIGKILL o perdita di corrente).
# Riga finale: CAMPAGNA=<stato> RIPRISTINO=<esito> BRACCI=<n>/4 USCITA=<codice>
#   2   RIPRISTINO=FALLITO (precedenza assoluta, stato conservato)
#   0   CAMPAGNA=COMPLETA: 4 bracci completi, correttezza OK, WORKLOAD_COMPARABILE=SI
#       (dati pronti; il
#       verdetto sulle PRESTAZIONI e' in analisi.txt, MAI nel codice d'uscita)
#   1   CAMPAGNA=FERMATA_CORRETTEZZA
#   3   CAMPAGNA=INCOMPLETA (braccio incompleto, CONFIG, isolamento a meta', swap,
#       lavoro non dimostrato uguale nei quattro bracci)
#   4   CAMPAGNA=NON_ESEGUITA (controlli a freddo, nessuna VM avviata)
#   130/143/129  CAMPAGNA=INTERROTTA
# Uso: sudo -n sh run-abba-retry-2vp.sh   (da root, come winrun)
B=/mnt/linuxulator2/vm/nested-work; N=$B/freebsd-nested/tools/nested
MOD_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9
LAT_SHA=c375c281519db0a6ec118b4cff02b9281f3db911bfa299db286126d418f8d108
PROVA_SHA=4913267ece3feb215b144a79efb79927b2d101ccb144a2eaed8b9d9121d9a0e6
AN_SHA=380fd1d3c86e70a311535697d055e85009f905762385e0f0ca4fba17c0d396d0
# carico (parere #86 §5): i file copiati in Windows a ogni braccio, hash dell'elenco sha256 -r
CARICO="kbuild4.sh kbuild-lavoro.sh gapmem.sh gapmon.c memmon.c"
CARICO_SHA=ed1bf5bb326be3a5ba9b5c890ae9f9bf64341884b0b258027d54e5e7455194ad
carico_sha() { (cd $B/faseA && sha256 -r $CARICO) | sha256 -q; }
PROVA=$B/run-abba-retry-prova.sh
PAUSA=${PAUSA:-60}
SWAP_ASSESTA=${SWAP_ASSESTA:-30}	# secondi di assestamento dopo swapoff/swapon
[ "$(id -u)" = 0 ] || { echo "va eseguito da root (sudo -n sh $0)"; exit 4; }
BASE=$B/logs/abba-retry2vp-$(date +%Y%m%d-%H%M)
mkdir -p "$BASE" || exit 4
R0="$BASE/riepilogo.txt"

K="vept_keep vept_verify_hpa vept_test_race vept_scan_hold_keep vept_scan_retries nested_shadow_vmcs nested_shadow_verify nested_fast_field_validate nested_shadow_inject nested_vpid_track nested_vpid12_flush"
PRIMA=$(for k in $K; do sysctl -n hw.vmm.vmx.$k; done | tr '\n' ' ')
{ echo "$K"; echo "$PRIMA"; } > "$BASE/sysctl-iniziali.txt"
: > "$BASE/bracci.txt"
RIPRISTINATO=0; RIP_ESITO=NON_ESEGUITO; AVVIATI=0; STATO=""
ripristina() {
	[ $RIPRISTINATO = 1 ] && return 0
	RIPRISTINATO=1
	set -- $PRIMA
	for k in $K; do sysctl hw.vmm.vmx.$k=$1 > /dev/null; shift; done
	ORA=$(for k in $K; do sysctl -n hw.vmm.vmx.$k; done | tr '\n' ' ')
	if [ "$ORA" = "$PRIMA" ]; then
		RIP_ESITO=OK; echo "RIPRISTINO=OK sysctl rimessi e riletti: $ORA" | tee -a "$R0"
	else
		RIP_ESITO=FALLITO; echo "RIPRISTINO=FALLITO ora '$ORA', attesi '$PRIMA'" | tee -a "$R0"
	fi
}
concludi() {	# $1 = segnale (vuoto se nessuno)
	ripristina
	n=$(/usr/bin/grep -c ' COMPLETA$' "$BASE/bracci.txt")
	if [ -n "$1" ]; then
		C=INTERROTTA; case $1 in INT) U=130;; TERM) U=143;; HUP) U=129;; esac
	elif [ $AVVIATI = 0 ]; then C=NON_ESEGUITA; U=4
	elif /usr/bin/grep -q ' CORRETTEZZA' "$BASE/bracci.txt"; then C=FERMATA_CORRETTEZZA; U=1
	elif [ "$n" = 4 ]; then C=COMPLETA; U=0
	else C=INCOMPLETA; U=3
	fi
	if [ "$n" -ge 1 ] && [ -x /usr/local/bin/python3 ]; then
		/usr/local/bin/python3 "$B/abba_retry_an.py" "$BASE" --retry A=1,B=2 > "$BASE/analisi.txt" 2>&1
		/usr/bin/grep -E '^(controlli|struttura|WORKLOAD|VERDETTO|EVIDENZA|RETRY2)|^compilazione' "$BASE/analisi.txt" | tee -a "$R0"
	fi
	# parere #86 §2: quattro bracci completi ma lavoro non dimostrato uguale ->
	# INCOMPLETA ai fini prestazionali (i dati restano, il confronto no)
	if [ "$C" = COMPLETA ] && ! /usr/bin/grep -q '^WORKLOAD_COMPARABILE=SI$' "$BASE/analisi.txt" 2>/dev/null; then
		echo "lavoro non dimostrato uguale nei quattro bracci: $(/usr/bin/grep '^WORKLOAD_COMPARABILE=' "$BASE/analisi.txt" 2>/dev/null)" | tee -a "$R0"
		C=INCOMPLETA; U=3
	fi
	[ "$RIP_ESITO" = OK ] || U=2
	echo "CAMPAGNA=$C RIPRISTINO=$RIP_ESITO BRACCI=$n/4 USCITA=$U" | tee -a "$R0"
	[ -n "$BASE" ] && [ -d "$BASE" ] && /usr/bin/find "$BASE" -type f -exec chmod a+r {} +
	(cd "$BASE" && /usr/bin/find . -type f ! -name SHA256SUMS -exec sha256 -r {} + > SHA256SUMS)
	trap - EXIT
	exit $U
}
ferma() { echo "STOP: $*" | tee -a "$R0"; concludi; }
segnale() {
	echo "INTERROTTO ($1)" | tee -a "$R0"
	# il braccio chiude DTrace e spegne Windows in modo ordinato: lo si ASPETTA
	[ -n "$PP" ] && { kill -TERM "$PP" 2>/dev/null; wait "$PP" 2>/dev/null; }
	concludi $1
}
trap 'ripristina' EXIT
trap 'segnale INT' INT
trap 'segnale TERM' TERM
trap 'segnale HUP' HUP

# Swap (parere #86 §3): prima di ogni braccio, FUORI dal tempo misurato. Se e'
# gia' vuoto, solo verifica. Altrimenti: memoria disponibile (libera + inattiva)
# almeno il DOPPIO dello swap usato, swapoff -a SENZA -f (mai forzare); su errore
# si riattivano i dispositivi registrati e la campagna si ferma; poi i
# dispositivi originali devono essere di nuovo attivi; 30 s di assestamento.
SWAPERR=""
swap_disp() { swapctl -l | awk 'NR > 1 {print $1}' | sort; }
swap_normalizza() {	# $1 = braccio
	f="$BASE/swap-$1.txt"
	{ echo "== prima $(date +%T)"; swapctl -l; swapinfo -k; sysctl vm.stats.vm.v_free_count vm.stats.vm.v_inactive_count hw.pagesize; } > "$f" 2>&1
	D0=$(swap_disp)
	[ -n "$D0" ] || { SWAPERR="nessun dispositivo di swap attivo"; return 1; }
	u=$(swapinfo -k | awk 'NR > 1 {s += $3} END {print s + 0}')
	if [ "$u" -eq 0 ]; then
		echo "swap gia' vuoto: nessun ciclo" >> "$f"
	else
		pg=$(sysctl -n hw.pagesize)
		disp=$(( ( $(sysctl -n vm.stats.vm.v_free_count) + $(sysctl -n vm.stats.vm.v_inactive_count) ) * pg / 1024 ))
		echo "swap usato ${u} KB, memoria disponibile ${disp} KB" >> "$f"
		[ "$disp" -ge $(( u * 2 )) ] || { SWAPERR="memoria disponibile ${disp} KB < 2 x swap usato ${u} KB"; return 1; }
		if ! swapoff -a >> "$f" 2>&1; then
			for d in $D0; do swapctl -l | awk '{print $1}' | /usr/bin/grep -qx "$d" || swapon "$d" >> "$f" 2>&1; done
			SWAPERR="swapoff fallito (dispositivi riattivati: $(swap_disp | tr '\n' ' '))"
			return 1
		fi
		for d in $D0; do swapon "$d" >> "$f" 2>&1; done
		sleep "$SWAP_ASSESTA"
	fi
	D1=$(swap_disp)
	{ echo "== dopo $(date +%T)"; swapctl -l; swapinfo -k; sysctl vm.stats.vm.v_free_count vm.stats.vm.v_inactive_count; } >> "$f" 2>&1
	[ "$D1" = "$D0" ] || { SWAPERR="dispositivi di swap diversi: prima '$D0', dopo '$D1'"; return 1; }
	return 0
}
# VM vive: NOME del programma (bhyve*, qemu-system*), non la riga di comando
vm_vive() { /bin/ps -ax -o pid= -o comm= -o args= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'; }
vmm_aperti() { for n in /dev/vmm/*; do [ -e "$n" ] || continue; fstat "$n" 2>/dev/null | sed 1d; done; }

echo "=== controlli a freddo ===" | tee -a "$R0"
[ "$(sha256 -q /boot/kernel/vmm-restore.ko)" = "$MOD_SHA" ] || ferma "modulo diverso da 27125f004917"
[ "$(sha256 -q $N/abba-invept-lat.d)" = "$LAT_SHA" ] || ferma "abba-invept-lat.d diversa da quella collaudata"
[ "$(sha256 -q $PROVA)" = "$PROVA_SHA" ] || ferma "run-abba-retry-prova.sh diverso da quello rivisto"
[ "$(sha256 -q $B/abba_retry_an.py)" = "$AN_SHA" ] || ferma "abba_retry_an.py diverso da quello collaudato"
[ "$(carico_sha)" = "$CARICO_SHA" ] || ferma "file del carico (faseA: $CARICO) diversi da quelli rivisti"
sysctl -n hw.vmm.vmx.nested_invept_opt >/dev/null 2>&1 && ferma "esiste un interruttore di elisione: build inattesa"
dtrace -e -s $N/abba-invept-lat.d 1 > "$BASE/lat-compila.txt" 2>&1 || ferma "abba-invept-lat.d non compila sul modulo installato"
v=$(vm_vive); [ -n "$v" ] && { echo "$v" | tee -a "$R0"; ferma "processo VM vivo: la vm0:12 dell'utente o altro (non si tocca)"; }
v=$(vmm_aperti); [ -n "$v" ] && { echo "$v" | tee -a "$R0"; ferma "nodo /dev/vmm aperto"; }
{
	echo "modulo $MOD_SHA"; echo "abba-invept-lat.d $LAT_SHA"; echo "prova $PROVA_SHA"; echo "analizzatore $AN_SHA"
	echo "carico $CARICO_SHA:"; (cd $B/faseA && sha256 -r $CARICO)
	echo "orchestratore $(sha256 -q $0)"; echo "sysctl iniziali ($K): $PRIMA"
	cpucontrol -m 0x8b /dev/cpuctl6; cpucontrol -i 0x1 /dev/cpuctl6
	sysctl kern.osrelease hw.vmm.vmx.vept_scan_budget_us; ls -la /dev/vmm; swapinfo -h
	sha256 $N/12-Windows-11-vm12-senza-gpu $N/../../../stage/current/sbin/bhyve 2>&1
} > "$BASE/baseline.txt" 2>&1

i=0
for riga in "A 1" "B 2" "B 2" "A 1"; do
	set -- $riga
	i=$((i + 1)); M=$1; R=$2; O=$BASE/$i-$M
	mkdir -p "$O"
	v=$(vm_vive); [ -n "$v" ] && { echo "$v" | tee -a "$R0"; ferma "VM viva prima del braccio $i"; }
	v=$(vmm_aperti); [ -n "$v" ] && ferma "nodo /dev/vmm aperto prima del braccio $i"
	swap_normalizza "$i" || ferma "normalizzazione dello swap prima del braccio $i: $SWAPERR"
	{ echo "== braccio $i ($M) retry=$R $(date +%T)"; swapinfo -h | tail -1; ps -axo pcpu,rss,comm -r | head -8; } >> "$BASE/attivita.txt"
	echo "######## braccio $i: $M (vept_scan_retries=$R) $(date +%T)" | tee -a "$R0"
	AVVIATI=$((AVVIATI + 1))
	env O="$O" MOD="$M" R="$R" sh "$PROVA" 480 2 > "$O/run.out" 2>&1 &
	PP=$!; wait $PP; PP=
	esito=$(/usr/bin/sed -n 's/^OUTPUT [^ ]* //p' "$O/run.out" | tail -1)
	echo "$i $M $R ${esito:-SENZA_ESITO}" >> "$BASE/bracci.txt"
	echo "   braccio $i ($M): ${esito:-SENZA_ESITO} ($(date +%T))" | tee -a "$R0"
	/usr/bin/grep -E "CHECKPOINT 05|^real|kernel rc|ext4:" "$O/run.out" | sed 's/^/   /' | tee -a "$R0"
	case "$esito" in
	COMPLETA) ;;
	CORRETTEZZA*) ferma "correttezza nel braccio $i: $esito" ;;
	*) ferma "braccio $i non completo: ${esito:-SENZA_ESITO}" ;;
	esac
	[ $i -lt 4 ] && sleep "$PAUSA"
done
echo "FINE: 4 bracci, nessuna corsa successiva automatica" | tee -a "$R0"
concludi
