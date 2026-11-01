#!/bin/sh
# sequenza-p3.sh -- Claude 01/11/2026. La sequenza del TEST DI PROVOCAZIONE di P3 sullo stadio 11 (decisione dell'utente
# del 01/11: «preparalo»): e' sequenza-wsl.sh (collaudata) con run-p3-kut.sh al posto delle corse Windows. Solo lo
# stadio 11 (sullo stadio 10 il test terrebbe il vCPU nel kernel per tutta la contesa), 1..3 sessioni, ombra spenta.
#   sh sequenza-wsl.sh --prova  <cartella nuova> <N corse 1..12> <ombra 0|1>    sola lettura, stampa lo sha da autorizzare
#   sh sequenza-wsl.sh --esegui <cartella nuova> <N> <ombra> <sha dell'elenco approvato>   (consenso dell'utente)
# Si lancia STACCATA: daemon -f -o <cartella>.log sh sequenza-wsl.sh --esegui ... (il diario e' il canale d'avanzamento).
# Sequenza: smoke originale -> scambio originale->stadio10 -> smoke C1 -> per ogni corsa: run-wsl-corsa.sh, classificazione;
# se vm0:12 e' rimasta (NODO_DELLA_SESSIONE) pulizia con --distruggi-da e riclassificazione (deve dire NESSUN_NODO);
# continuita' -> ritorno stadio10->originale -> smoke. La VM e' senza passthrough: il ritorno resta uno scambio a caldo
# (il runner verifica hw.vmm.iommu.initialized = 0 prima di ogni corsa).
#
# REGOLA D'AVANZAMENTO (riesame Opus, par. 3 azione 1): ogni invocazione di uno strumento scrive nel DIARIO.txt una
# riga INIZIO prima e una riga FINE con ora e codice d'uscita dopo, riuscita o no. Qualunque uscita != 0 di uno
# strumento ferma la sequenza; dopo, SOLO il recupero qui sotto e il ritorno. Nessun passo viene ripetuto dallo script.
# Un passo che lo script NON ha invocato (nessuna riga INIZIO nel diario) e con lo stato invariato si puo' ripetere UNA
# volta, identico, solo rilanciando la sequenza dall'inizio su una cartella nuova, con nuova autorizzazione.
#
# Le variabili globali hanno nomi propri (REC_S, TENTATA, FASE): le funzioni t_* (e il finto) non le toccano.
# RECUPERO (dopo uno STOP successivo allo scambio): classificazione; NODO_DELLA_SESSIONE -> --distruggi-da, solo se la
# distruzione non e' gia' stata tentata in questa sequenza per quella sessione; poi riclassificazione; NESSUN_NODO ->
# ritorno stadio10->originale + smoke originale; GIA_RIPRISTINATO -> smoke originale; OPERATORE/EMERGENZA o qualunque
# fallimento del recupero -> nessuna azione, uscita 6.
#
# Uscita: 0 sequenza completa e host sull'originale | 4 STOP, recupero riuscito e host sull'originale (o nulla
# cambiato) | 6 OPERATORE: host NON garantito sull'originale, nessuna azione ulteriore | 130/143/129 interrotta da
# segnale: nessuna azione ulteriore dopo il segnale (il diario dice a quale invocazione), operatore.
# SEGNALI: in sh la trappola di un segnale ricevuto mentre gira uno strumento in primo piano scatta DOPO che lo
# strumento e' finito. Un segnale al solo processo della sequenza lascia quindi finire lo strumento in corso (nessuno
# scambio a meta'); un segnale al GRUPPO raggiunge anche lo strumento, che ha le sue difese (runner: trappole C2;
# modulo-caldo: stati d'emergenza in logs/modulo-caldo/stato.txt).
# STRUMENTI APPROVATI (parere Opus sull'incidente, par. 4.2): all'avvio, prima di qualunque invocazione, ogni file di
# APPROVATI-sequenza.sha256 (generato da approva-strumenti.sh quando gli strumenti sono rivisti) deve avere lo sha
# registrato; altrimenti STOP 4. Lo sha dell'elenco va nel testo dell'autorizzazione (in futuro nel gettone).
# SEQ_FINTO (solo collaudo, test-sequenza-wsl.sh): file che ridefinisce le funzioni t_*; uscita SIMULATA: 2 al posto
# di 0, mai 0; ogni riga del diario e la riga finale dicono SIMULATA.
set -u
W=/mnt/linuxulator2/vm/wsl2/fbsd
C=$W/caldo
umask 022
t_ora()     { /bin/date '+%F %T'; }
T_SMOKE=$C/smoke-modulo.sh; T_CALDO=$C/modulo-caldo.sh; T_RUNNER=$W/run-p3-kut.sh; T_RESIDUO=$C/vmm-residuo.sh
t_smoke()   { sh "$T_SMOKE" "$@"; }
t_caldo()   { sh "$T_CALDO" "$@"; }
t_runner()  { sh "$T_RUNNER" "$@"; }
t_residuo() { sh "$T_RESIDUO" "$@"; }
t_sha()     { /sbin/sha256 -q "$1" 2>/dev/null; }
SIM=""
if [ -n "${SEQ_FINTO:-}" ]; then
	# 31/10/2026, dopo l'incidente del collaudo: DUE reti in questo script (oltre alla guardia degli strumenti veri e
	# all'utente collaudo senza sudo). Rete A (parere Opus par. 3.3): i percorsi degli strumenti puntano a una TRAPPOLA
	# che registra in $SEQ_TRAPPOLE e non agisce: una trappola scattata = una rete ha ceduto. Rete B: prima tutte le
	# t_* rifiutano, poi il finto le ridefinisce.
	T_SMOKE=$W/trappola-strumento.sh; T_CALDO=$T_SMOKE; T_RUNNER=$T_SMOKE; T_RESIDUO=$T_SMOKE
	for x in t_smoke t_caldo t_runner t_residuo; do eval "$x() { echo \"SIMULATA: $x non ridefinita, nessuna azione reale\"; return 6; }"; done
	. "$SEQ_FINTO"; SIM=" SIMULATA"
fi

uso() { echo "uso: $0 --prova <cartella nuova> <N corse 1..12> <ombra 0|1> [stadio10|stadio11] | --esegui <cartella nuova> <N> <ombra> <sha dell'elenco approvato> [stadio10|stadio11]"; exit 4; }
MODO=${1:-}
case "$MODO" in
--prova)  [ $# = 4 ] || [ $# = 5 ] || uso; SHA_AUT=""; STADIO=${5:-stadio11};;
--esegui) [ $# = 5 ] || [ $# = 6 ] || uso; SHA_AUT=$5; STADIO=${6:-stadio11}
	echo "$SHA_AUT" | /usr/bin/grep -qx '[0-9a-f]\{64\}' || { [ -n "$SIM" ] && [ "$SHA_AUT" = finto ]; } || uso;;
*) uso;;
esac
# parere #172 di Astra: la qualifica limitata dello stadio 11 usa la stessa sequenza; lo stadio e' nell'autorizzazione
case "$STADIO" in stadio11) ;; *) echo "STOP: il test di provocazione di P3 gira solo sullo stadio11, non '$STADIO'"; exit 4;; esac
SEQ=$2; NC=$3; OMBRA=$4
case "$NC" in [1-3]) ;; *) echo "STOP: sessioni fra 1 e 3, non '$NC'"; exit 4;; esac
case "$OMBRA" in 0) RMODO=--esegui;; *) echo "STOP: ombra solo 0 nel test di P3, non '$OMBRA'"; exit 4;; esac
case "$SEQ" in
/mnt/linuxulator2/vm/wsl2/fbsd/logs/*) ;;
/mnt/linuxulator2/vm/wsl2/fbsd/collaudi/*) [ -n "$SIM" ] || { echo "STOP: collaudi/ e' solo per il modo finto"; exit 4; };;
*) echo "STOP: la cartella deve stare in $W/logs (ZFS)"; exit 4;;
esac
[ -e "$SEQ" ] && { echo "STOP: $SEQ esiste gia'"; exit 4; }
LISTA=$(/usr/bin/jot -s " " "$NC" 1)
mkdir -p "$SEQ" || { echo "STOP: $SEQ non creabile"; exit 4; }
D=$SEQ/DIARIO.txt
n=0
diario() { echo "$(t_ora)$SIM $*" >> "$D"; }
# inv <nome> <funzione> <argomenti...>: una invocazione = INIZIO + FINE rc nel diario, uscita in NN-<nome>.txt
inv() {
	nome=$1; shift; n=$((n+1)); f=$SEQ/$(printf '%02d' $n)-$nome.txt
	diario "INIZIO $n $nome: $*"
	"$@" < /dev/null > "$f" 2>&1; r=$?
	diario "FINE $n $nome rc=$r ($(tail -1 "$f" | cut -c1-160))"
	echo "$(printf '%02d' $n) $nome rc=$r: $(tail -1 "$f" | cut -c1-160)"
	ULTIMO=$f
	return $r
}
ramo() { sed -n 's/^RAMO=\([A-Z_]*\) .*/\1/p' "$1" | head -1; }
fine() {	# fine <codice reale> <motivo>
	c=$1; shift
	[ -n "$SIM" ] && [ "$c" = 0 ] && c=2
	diario "ESITO $c: $*"
	echo "SEQUENZA$SIM ESITO $c: $*"
	exit $c
}
FASE=prima-dello-scambio
for s in HUP:129 INT:130 TERM:143; do
	trap "diario 'INTERROTTA da SIG${s%%:*} (fase '\$FASE', ultima invocazione '\$n'): nessuna azione ulteriore, operatore'; echo 'SEQUENZA$SIM INTERROTTA: operatore'; exit ${s#*:}" ${s%%:*}
done

[ -n "$SIM" ] && { SEQ_TRAPPOLE=$SEQ/TRAPPOLE.txt; export SEQ_TRAPPOLE; }
diario "SEQUENZA $MODO test di provocazione di P3 su $STADIO: $NC corse, ombra $OMBRA ($RMODO) in $SEQ"
# strumenti approvati: verificati, non solo registrati
APPROVATI=$W/APPROVATI-sequenza.sha256
[ -n "$SIM" ] && [ -n "${SEQ_APPROVATI:-}" ] && APPROVATI=$SEQ_APPROVATI
[ -r "$APPROVATI" ] || fine 4 "elenco degli strumenti approvati assente: $APPROVATI"
NA=0
while read AH AF; do
	case "$AH" in ''|\#*) continue;; esac
	NA=$((NA+1)); AS=$(t_sha "$AF")
	[ "$AS" = "$AH" ] || fine 4 "strumento diverso da quello approvato: $AF (sha ${AS:-illeggibile}, approvato $AH)"
	diario "approvato $AH $AF"
done < "$APPROVATI"
[ $NA -gt 0 ] || fine 4 "elenco degli strumenti approvati vuoto: $APPROVATI"
SHA_EL=$(t_sha "$APPROVATI")
diario "strumenti approvati: $NA, elenco $APPROVATI sha $SHA_EL"
if [ "$MODO" = --esegui ]; then
	[ "$SHA_EL" = "$SHA_AUT" ] || fine 4 "lo sha dell'elenco approvato ($SHA_EL) non e' quello dell'autorizzazione ($SHA_AUT): nulla invocato"
	diario "sha dell'elenco = sha dell'autorizzazione"
else
	echo "sha dell'elenco approvato, da scrivere nel testo dell'autorizzazione: $SHA_EL"
fi

if [ "$MODO" = --prova ]; then
	inv smoke-originale t_smoke originale || fine 4 "prova: smoke originale non coerente"
	inv caldo-prova t_caldo --prova originale $STADIO || fine 4 "prova: preflight dello scambio rifiutato"
	inv runner-prova t_runner --prova $SEQ/prova-corsa $STADIO
	r=$?; [ $r = 6 ] || [ $r = 0 ] || fine 4 "prova: preflight della corsa rc=$r"
	fine 0 "prova: nessuna azione sull'host"
fi

# --- recupero: solo dopo uno STOP successivo allo scambio ---
TENTATA=""	# sessioni per cui --distruggi-da e' gia' stato invocato
recupero() {	# recupero <sessione>|nessuna <motivo dello STOP>
	REC_S=$1; shift; FASE=recupero
	diario "STOP: $*; RECUPERO"
	inv recupero-classifica t_residuo --classifica-ritorno "$REC_S" || fine 6 "STOP ($*); classificazione del recupero fallita"
	g=$(ramo "$ULTIMO")
	if [ "$g" = NODO_DELLA_SESSIONE ]; then
		case " $TENTATA " in *" $REC_S "*) fine 6 "STOP ($*); la VM della sessione e' ancora presente dopo una distruzione gia' tentata: operatore";; esac
		TENTATA="$TENTATA $REC_S"
		inv recupero-distruggi t_residuo --distruggi-da "$REC_S" || fine 6 "STOP ($*); distruzione del recupero fallita"
		inv recupero-riclassifica t_residuo --classifica-ritorno "$REC_S" || fine 6 "STOP ($*); riclassificazione del recupero fallita"
		g=$(ramo "$ULTIMO")
	fi
	case "$g" in
	NESSUN_NODO)
		inv recupero-ritorno t_caldo --esegui $STADIO originale; r=$?
		case $r in 0|5) ;; *) fine 6 "STOP ($*); ritorno del recupero rc=$r";; esac
		inv recupero-smoke-originale t_smoke originale || fine 6 "STOP ($*); smoke originale dopo il recupero non coerente"
		fine 4 "STOP ($*); recupero riuscito, host sull'originale";;
	GIA_RIPRISTINATO)
		inv recupero-smoke-originale t_smoke originale || fine 6 "STOP ($*); smoke originale non coerente"
		fine 4 "STOP ($*); host gia' sull'originale";;
	*)	fine 6 "STOP ($*); ramo '$g': nessuna azione, operatore";;
	esac
}

# --- sequenza ---
inv smoke-originale t_smoke originale || fine 4 "smoke originale iniziale non coerente: nulla fatto"
inv scambio t_caldo --esegui originale $STADIO; r=$?
case $r in
0) ;;
4) fine 4 "scambio rifiutato (rc 4): nulla cambiato";;
5) inv smoke-originale-dopo-scambio-fallito t_smoke originale || fine 6 "scambio fallito (rc 5) e smoke originale non coerente"
   fine 4 "scambio fallito (rc 5), tornato all'originale verificato";;
*) fine 6 "scambio rc=$r: operatore";;
esac
FASE=$STADIO
inv smoke-C1 t_smoke $STADIO || recupero nessuna "smoke C1 di $STADIO non coerente"
for k in $LISTA; do
	FASE=corsa-$k; S=$SEQ/corsa$k
	inv corsa-$k t_runner $RMODO $S $STADIO || recupero $S "corsa $k rc=$?"
	inv classifica-$k t_residuo --classifica-ritorno $S || recupero $S "classificazione dopo la corsa $k"
	g=$(ramo "$ULTIMO")
	if [ "$g" = NODO_DELLA_SESSIONE ]; then		# vm0:12 rimasta dopo lo spegnimento: si distrugge solo questa
		TENTATA="$TENTATA $S"
		inv pulizia-$k t_residuo --distruggi-da $S || recupero $S "pulizia dopo la corsa $k"
		inv riclassifica-$k t_residuo --classifica-ritorno $S || recupero $S "riclassificazione dopo la corsa $k"
		g=$(ramo "$ULTIMO")
	fi
	[ "$g" = NESSUN_NODO ] || recupero $S "dopo la corsa $k il ramo e' '$g', non NESSUN_NODO"
	inv continuita-$k t_smoke $STADIO --continuita $S || recupero $S "continuita' dopo la corsa $k"
done
FASE=ritorno
inv ritorno t_caldo --esegui $STADIO originale; r=$?
case $r in
0) ;;
5) inv smoke-originale-dopo-ritorno-fallito t_smoke originale || fine 6 "ritorno fallito (rc 5) e smoke originale non coerente"
   fine 4 "ritorno fallito (rc 5) ma tornato all'originale verificato";;
*) fine 6 "ritorno rc=$r: operatore";;
esac
inv smoke-originale-finale t_smoke originale || fine 6 "smoke originale finale non coerente"
fine 0 "campagna completa su $STADIO: $NC corse, ombra $OMBRA; host sull'originale"
