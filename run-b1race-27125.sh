#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-b1race-27125.sh.non-conforme
echo "INERTE: run-b1race-27125.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-b1race-27125.sh.non-conforme" >&2; exit 4
# run-b1race-27125.sh -- Claude 26/10/2026 notte, pareri #82, #83 e #84: b1_race
# con iniezione deterministica (vept_test_race) sul modulo 27125f004917, cinque
# prove A-E, vept_keep=1 e vept_verify_hpa=1. SCOPE: 5 VM QEMU (vm2, la VM dei
# kvm-unit-tests), una per prova; la A e' un CANCELLO: se non e' PASS in tutte e
# tre le dimensioni (FUNCTIONAL, PATH, INTEGRITA) la campagna si ferma.
# Verdetti separati FUNCTIONAL e PATH (verdetto-b1race.py) con correlazione ED
# ESCLUSIVITA' per operazione (diag83.d). Barriere per prova (parere #84 §4):
# contatori iniziali letti SENZA VM; DTrace PRONTA prima di QEMU; dopo kut-run
# si attende che QEMU sia uscito e vm2 chiuso, POI si ferma DTrace e si
# leggono i contatori finali, di nuovo SENZA VM. -smp richiesto (lista)
# incrociato con quello eseguito (riga di comando di QEMU).
# Ripristino idempotente e verificato dei sysctl INIZIALI anche su errore e
# su INT/TERM/HUP (non su SIGKILL o perdita di corrente).
# CODICE D'USCITA (parere #84 §3), con la riga finale
#   CAMPAGNA=<stato> RIPRISTINO=<esito> PROVE=<n>/5 USCITA=<codice>:
#   2   RIPRISTINO=FALLITO, qualunque altro esito (precedenza assoluta)
#   0   CAMPAGNA=PASS: 5 prove FUNCTIONAL_PASS + PATH_PASS + INTEGRITA OK
#   1   CAMPAGNA=FAIL: almeno un FUNCTIONAL_FAIL o PATH_FAIL
#   3   CAMPAGNA=INCONCLUSIVE: nessun FAIL, ma una prova non PASS o meno di 5
#       prove eseguite (cancello A, STOP a meta')
#   4   CAMPAGNA=NON_ESEGUITA: STOP ai controlli a freddo, nessuna VM avviata
#   130/143/129  CAMPAGNA=INTERROTTA da SIGINT/SIGTERM/SIGHUP
# Nessun retry, nessuna corsa successiva automatica.
W=/mnt/linuxulator2/vm/wsl2/linux
T=$W/freebsd-nested/tools/nested
cd $W || exit 1
MOD_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9
FLAT=$W/kut/vmxc-plain.flat
FLAT_SHA=848b0410e94ca86be1b06a7288f6c80c1de8f3e90eec4a2872e49afbade5c7a5
D83_SHA=afa440c33f54bb9882b7fc3f7ab17c067241fc976fcc6074b0bf8affb945b04e
VER_SHA=4d3309d0c4563d0f00afe6994db0c1d69ced3ba6f7477bc4ebad4345e3d56411
L=$T/kut-b1race-27125.list
EV=$W/evidenze-b1race-27125/serie-1
VMPAT='[b]hyve|[q]emu-system'		# processi VM (la parentesi evita il grep stesso)
BARR_TIMEOUT=${BARR_TIMEOUT:-60}	# secondi d'attesa per l'uscita di QEMU
mkdir -p $EV || exit 1
[ -e $EV/riepilogo.txt ] && { echo "STOP: serie gia' fatta ($EV)"; exit 4; }

# sysctl toccati: valori INIZIALI salvati e rimessi alla fine
S="hw.vmm.vmx.vept_keep hw.vmm.vmx.vept_verify_hpa hw.vmm.vmx.vept_scan_retries hw.vmm.vmx.vept_test_race hw.vmm.vmx.nested_diag58"
PRIMA=$(/sbin/sysctl -n $S | /usr/bin/tr '\n' ' ')
echo "$S" > $EV/sysctl-iniziali.txt
echo "$PRIMA" >> $EV/sysctl-iniziali.txt
: > $EV/esiti.txt
RIPRISTINATO=0
RIP_ESITO=NON_ESEGUITO
AVVIATE=0
ripristina() {
	[ $RIPRISTINATO = 1 ] && return 0	# idempotente: EXIT dopo un segnale
	RIPRISTINATO=1
	set -- $PRIMA
	sudo -n /sbin/sysctl hw.vmm.vmx.vept_test_race=$4 hw.vmm.vmx.vept_keep=$1 hw.vmm.vmx.vept_verify_hpa=$2 \
	    hw.vmm.vmx.vept_scan_retries=$3 hw.vmm.vmx.nested_diag58=$5 >/dev/null
	ORA=$(/sbin/sysctl -n $S | /usr/bin/tr '\n' ' ')
	if [ "$ORA" = "$PRIMA" ]; then
		RIP_ESITO=OK
		echo "RIPRISTINO=OK sysctl rimessi e riletti: $ORA" | /usr/bin/tee -a $EV/riepilogo.txt
	else
		RIP_ESITO=FALLITO
		echo "RIPRISTINO=FALLITO ora '$ORA', attesi '$PRIMA'" | /usr/bin/tee -a $EV/riepilogo.txt
	fi
}
# stato della campagna dalle prove ESEGUITE (esiti.txt: prova FUNCTIONAL PATH INTEGRITA)
concludi() {	# $1 = segnale (vuoto se nessuno)
	ripristina
	n=$(/usr/bin/grep -c . $EV/esiti.txt)
	if [ -n "$1" ]; then
		C=INTERROTTA; case $1 in INT) U=130;; TERM) U=143;; HUP) U=129;; esac
	elif [ $AVVIATE = 0 ]; then
		C=NON_ESEGUITA; U=4
	elif /usr/bin/grep -qE '_FAIL' $EV/esiti.txt; then
		C=FAIL; U=1
	elif [ "$n" = 5 ] && [ "$(/usr/bin/grep -c '^[A-E] FUNCTIONAL_PASS PATH_PASS OK$' $EV/esiti.txt)" = 5 ]; then
		C=PASS; U=0
	else
		C=INCONCLUSIVE; U=3
	fi
	[ "$RIP_ESITO" = OK ] || U=2
	echo "CAMPAGNA=$C RIPRISTINO=$RIP_ESITO PROVE=$n/5 USCITA=$U" | /usr/bin/tee -a $EV/riepilogo.txt
	trap - EXIT
	exit $U
}
ferma() { echo "STOP: $*" | /usr/bin/tee -a $EV/riepilogo.txt; concludi; }
segnale() {
	echo "INTERROTTO ($1)" | /usr/bin/tee -a $EV/riepilogo.txt
	[ -n "$CAMP" ] && kill $CAMP 2>/dev/null
	ferma_dtrace
	concludi $1
}
# DTrace si ferma e si ASPETTA: la traccia deve avere END/CHIUSA prima di concludere
ferma_dtrace() { [ -n "$DT" ] && { sudo -n kill -TERM $DT 2>/dev/null; wait $DT 2>/dev/null; DT=; }; }
trap 'ripristina' EXIT
trap 'segnale INT' INT
trap 'segnale TERM' TERM
trap 'segnale HUP' HUP

nodi() { /bin/ls /dev/vmm 2>/dev/null | /usr/bin/sort; }
vm_vive() { sudo -n /bin/ps -axww -o pid= -o command= | /usr/bin/grep -E "$VMPAT"; }
vmm_aperti() {
	for v in /dev/vmm/*; do
		[ -e "$v" ] || continue
		sudo -n /usr/bin/fstat "$v" 2>/dev/null | /usr/bin/sed 1d
	done
}
senza_vm() { [ -z "$(vm_vive)" ] && [ -z "$(vmm_aperti)" ]; }

echo "=== controlli a freddo ==="
[ "$(/sbin/sha256 -q /boot/kernel/vmm-restore.ko)" = "$MOD_SHA" ] || ferma "modulo diverso da 27125f004917"
[ "$(/sbin/sha256 -q $FLAT)" = "$FLAT_SHA" ] || ferma "vmxc-plain.flat diverso"
[ "$(/sbin/sha256 -q $T/diag83.d)" = "$D83_SHA" ] || ferma "diag83.d diverso da quello collaudato"
[ "$(/sbin/sha256 -q $T/verdetto-b1race.py)" = "$VER_SHA" ] || ferma "verdetto-b1race.py diverso da quello collaudato"
/usr/local/bin/python3 $T/verdetto-b1race.py --autotest > $EV/autotest-oracolo.txt 2>&1 || ferma "autotest dell'oracolo fallito"
/sbin/sysctl -n hw.vmm.vmx.nested_invept_opt >/dev/null 2>&1 && ferma "esiste un interruttore di elisione: build inattesa"
sudo -n /usr/sbin/dtrace -e -s $T/diag83.d > $EV/diag83-compila.txt 2>&1 || ferma "diag83.d non compila sul modulo installato"
SMPL=$(/usr/bin/awk -F'|' '$1 ~ /^b1_race/ {gsub(/[[:space:]]/, "", $5); print $5}' $L)
[ "$SMPL" = 1 ] || ferma "la lista non chiede -smp 1 (trovato '$SMPL')"
v=$(vm_vive); [ -n "$v" ] && { echo "$v"; ferma "processo VM vivo (i contatori sono globali)"; }
v=$(vmm_aperti); [ -n "$v" ] && { echo "$v"; ferma "nodo /dev/vmm aperto da un processo"; }
NODI0=$(nodi | /usr/bin/tr '\n' ' ')
{
	echo "modulo $MOD_SHA"; echo "flat $FLAT_SHA (selettore vmx_ept_b1_race_test)"
	echo "diag83.d $D83_SHA"; echo "verdetto-b1race.py $VER_SHA"; echo "lista $(/sbin/sha256 -q $L) (-smp richiesto $SMPL)"
	echo "script $(/sbin/sha256 -q $0)"; echo "sysctl iniziali ($S): $PRIMA"
	echo "nodi /dev/vmm preesistenti: ${NODI0:-nessuno}"
	sudo -n /usr/sbin/cpucontrol -m 0x8b /dev/cpuctl6
	sudo -n /usr/sbin/cpucontrol -i 0x1 /dev/cpuctl6
	/sbin/sysctl kern.osrelease hw.vmm.vmx.vept_scan_budget_us; /bin/ls -la /dev/vmm
} > $EV/baseline.txt 2>&1

ctr() { /sbin/sysctl hw.vmm.vmx | /usr/bin/grep -E '^hw.vmm.vmx.(vept_scan_|vept_test_race_injected|vept_keep_|vept_leaves_zapped_|vept_t_attempt)' | /usr/bin/sed 's/^hw.vmm.vmx.//'; }
valore() { /usr/bin/sed -n "s/^$1=\([A-Z_]*\).*/\1/p" $2; }

# prova | vept_test_race | vept_scan_retries
for riga in "A 0 1" "B 1 0" "C 1 1" "D 2 1" "E 2 2"; do
	set -- $riga
	P=$1; X=$2; R=$3; O=$EV/$P; mkdir -p $O
	echo "=== prova $P (vept_test_race=$X, vept_scan_retries=$R), 1 VM ==="
	nodi > $O/vmm-prima.txt
	sudo -n /sbin/sysctl hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_verify_hpa=1 hw.vmm.vmx.vept_scan_retries=$R \
	    hw.vmm.vmx.vept_test_race=$X >/dev/null || ferma "sysctl ($P)"
	[ "$(/sbin/sysctl -n hw.vmm.vmx.vept_keep hw.vmm.vmx.vept_verify_hpa hw.vmm.vmx.vept_scan_retries hw.vmm.vmx.vept_test_race | /usr/bin/tr '\n' ' ')" = "1 1 $R $X " ] || ferma "sysctl non applicati ($P)"
	/sbin/sysctl hw.vmm.vmx.vept_keep hw.vmm.vmx.vept_verify_hpa hw.vmm.vmx.vept_scan_retries hw.vmm.vmx.vept_test_race > $O/configurazione.txt
	: > $O/barriere.txt
	# finestra iniziale: contatori letti SENZA VM (prima e dopo la lettura)
	senza_vm && { ctr > $O/prima; senza_vm; } && b=OK || b="NO VM viva alla lettura iniziale"
	echo "BARRIERA_FINESTRA_PRIMA=$b" >> $O/barriere.txt
	[ "$b" = OK ] || ferma "VM viva nella finestra iniziale ($P)"
	: > $O/diag83.out
	sudo -n /usr/sbin/dtrace -s $T/diag83.d -o $O/diag83.out 2> $O/diag83.err &
	DT=$!
	i=0
	until /usr/bin/grep -q '== TRACCIA PRONTA ==' $O/diag83.out 2>/dev/null; do
		i=$((i + 1))
		[ $i -gt 30 ] && { ferma_dtrace; ferma "DTrace non pronto in 15 s ($P)"; }
		sleep 0.5
	done
	# avvio: PRONTA acquisita e ancora nessuna VM prima di lanciare QEMU
	senza_vm && b=OK || b="NO VM comparsa prima del lancio"
	echo "BARRIERA_AVVIO=$b" >> $O/barriere.txt
	[ "$b" = OK ] || { ferma_dtrace; ferma "VM comparsa prima del lancio ($P)"; }
	/bin/ls $W/logs/kut-*-b1_race.serial 2>/dev/null | /usr/bin/sort > $O/seriali-prima.txt
	# argomenti REALI di QEMU (numero di vCPU), campionati durante la corsa
	( n=0; while [ $n -lt 600 ]; do
		a=$(/bin/ps -axww -o pid= -o command= | /usr/bin/grep '[q]emu-system-x86_64')
		[ -n "$a" ] && { echo "$a" > $O/qemu-args.txt; break; }
		n=$((n + 1)); sleep 0.2
	done ) &
	CAMP=$!
	AVVIATE=$((AVVIATE + 1))
	sudo -n env TEST_CPUS=6 /bin/sh $W/kutvpid/kut-run.sh --nested $L > $O/kut-run.out 2>&1
	# chiusura: QEMU uscito e nessun nodo aperto, POI si fermano il
	# campionatore (che deve poter vedere un QEMU sopravvissuto a kut-run) e DTrace
	i=0; b=OK
	until senza_vm; do
		i=$((i + 1))
		[ $i -gt $((BARR_TIMEOUT * 5)) ] && { b="NO VM ancora viva dopo ${BARR_TIMEOUT} s"; break; }
		sleep 0.2
	done
	kill $CAMP 2>/dev/null; wait $CAMP 2>/dev/null; CAMP=
	echo "BARRIERA_CHIUSURA=$b" >> $O/barriere.txt
	sudo -n kill -TERM $DT; wait $DT 2>/dev/null
	sudo -n kill -0 $DT 2>/dev/null && b="NO dtrace ancora vivo" || b=OK
	DT=
	echo "BARRIERA_DTRACE_CHIUSO=$b" >> $O/barriere.txt
	sudo -n /sbin/sysctl hw.vmm.vmx.vept_test_race=0 >/dev/null
	[ "$(/sbin/sysctl -n hw.vmm.vmx.vept_test_race)" = 0 ] || ferma "vept_test_race non rimesso a 0 ($P)"
	# finestra finale: contatori letti SENZA VM
	senza_vm && { ctr > $O/dopo; senza_vm; } && b=OK || { [ -s $O/dopo ] || ctr > $O/dopo; b="NO VM viva alla lettura finale"; }
	echo "BARRIERA_FINESTRA_DOPO=$b" >> $O/barriere.txt
	nodi > $O/vmm-dopo.txt
	/usr/bin/paste $O/prima $O/dopo | /usr/bin/awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "%-38s %+d\n", $1, d}' > $O/delta
	# seriale: esattamente UNO nuovo, altrimenti nessuno (-> INCONCLUSIVE)
	/bin/ls $W/logs/kut-*-b1_race.serial 2>/dev/null | /usr/bin/sort > $O/seriali-dopo.txt
	nuovi=$(/usr/bin/comm -13 $O/seriali-prima.txt $O/seriali-dopo.txt)
	ns=$(echo "$nuovi" | /usr/bin/grep -c .)
	if [ "$ns" = 1 ]; then
		SER=$O/$(basename "$nuovi")
		/bin/cp -n "$nuovi" $O/ || SER=$O/SERIALE-ASSENTE
	else
		SER=$O/SERIALE-ASSENTE; echo "seriali nuovi: $ns ($nuovi)" > $SER.txt
	fi
	[ -s $O/qemu-args.txt ] || echo "argomenti di QEMU non campionati" > $O/qemu-args.txt
	kv=$(/usr/bin/awk '$1=="b1_race" {print $2}' $O/kut-run.out)
	/usr/local/bin/python3 $T/verdetto-b1race.py $P $O/diag83.out $O/diag83.err $SER $O/prima $O/dopo \
	    --qemu-args $O/qemu-args.txt --smp-lista $SMPL --barriere $O/barriere.txt > $O/verdetto.txt 2>&1
	F=$(valore FUNCTIONAL $O/verdetto.txt); PV=$(valore PATH $O/verdetto.txt)
	IG=$(/usr/bin/sed -n 's/^INTEGRITA \(OK\).*/\1/p; s/^INTEGRITA NO.*/NO/p' $O/verdetto.txt)
	echo "$P ${F:-ASSENTE} ${PV:-ASSENTE} ${IG:-ASSENTE}" >> $EV/esiti.txt
	nv=$(/usr/bin/comm -3 $O/vmm-prima.txt $O/vmm-dopo.txt | /usr/bin/tr -d '\t' | /usr/bin/grep -vx vm2)
	{
		echo "== $P (race=$X retry=$R) runner=$kv seriale=$(basename $SER)"
		/usr/bin/grep -E '^(FUNCTIONAL|PATH|RETRY2|INTEGRITA|SMP)' $O/verdetto.txt | /usr/bin/sed 's/^/   /'
		/usr/bin/grep -v '=OK$' $O/barriere.txt | /usr/bin/sed 's/^/   ATTENZIONE: /'
		[ -n "$nv" ] && echo "   ATTENZIONE: nodi /dev/vmm cambiati oltre vm2: $nv"
	} | /usr/bin/tee -a $EV/riepilogo.txt
	/usr/bin/grep -E '^(TRACCIA|ESCLUSE|INIEZIONI|DESIGNATA|DELTA)' $O/verdetto.txt | /usr/bin/sed 's/^/   op| /'
	[ -f "$SER" ] && /usr/bin/grep -E '^(PASS|FAIL|XPASS)|B1RACE: fine|^SUMMARY' $SER | /usr/bin/sed 's/^/   L1| /'
	{
		echo "prova $P vept_test_race=$X vept_scan_retries=$R"
		echo "modulo $MOD_SHA flat $FLAT_SHA diag83.d $D83_SHA oracolo $VER_SHA"
		echo "seriale $(basename $SER)"; echo "qemu: $(/usr/bin/head -1 $O/qemu-args.txt)"
		echo "smp richiesto $SMPL"; /bin/cat $O/barriere.txt
		echo "nodi /dev/vmm prima: $(/usr/bin/tr '\n' ' ' < $O/vmm-prima.txt) dopo: $(/usr/bin/tr '\n' ' ' < $O/vmm-dopo.txt)"
		echo "esito: FUNCTIONAL=$F PATH=$PV INTEGRITA=$IG"
	} > $O/manifest.txt
	/sbin/sha256 -r $O/* > $O/SHA256SUMS 2>/dev/null
	[ -n "$nv" ] && ferma "nodi /dev/vmm cambiati oltre vm2 ($P): $nv"
	/usr/bin/grep -q '^BARRIERA_CHIUSURA=NO' $O/barriere.txt && ferma "VM ancora viva dopo la prova $P"
	# cancello (parere #84 §5): la A deve passare in tutte e tre le dimensioni
	[ $P = A ] && [ "$F $PV $IG" != "FUNCTIONAL_PASS PATH_PASS OK" ] && ferma "cancello A non superato: $F $PV INTEGRITA=$IG (analisi offline, B-E non eseguite)"
done

/bin/ls -la /dev/vmm >> $EV/riepilogo.txt
/sbin/sha256 -r $EV/*.txt > $EV/SHA256SUMS 2>/dev/null
echo "FINE: 5 prove, nessuna corsa successiva automatica" | /usr/bin/tee -a $EV/riepilogo.txt
concludi
