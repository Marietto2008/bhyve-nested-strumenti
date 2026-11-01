#!/bin/sh
# sequenza-kut.sh -- Claude 31/10/2026, riesame di Opus sulla sequenza A -> A-shadow -> B (par. 3, azioni 1 e 2).
# La sequenza autorizzata gira come UN UNICO script sh, con le regole d'arresto scritte qui: nessuna riga composta a
# mano nella shell interattiva, nessun argomento trascritto dall'operatore (vm2 si distrugge con
# vmm-residuo.sh --distruggi-da <sessione>, che ricava l'istanza dal manifest e dallo stato).
#
#   sh sequenza-kut.sh --prova  <cartella nuova> <passi>   sola lettura: preflight di scambio e runner, smoke originale
#   sh sequenza-kut.sh --esegui <cartella nuova> <passi> <sha dell'elenco approvato>   (consenso dell'utente)
#        lo sha e' quello scritto nel TESTO dell'autorizzazione (parere Opus sulla separazione, par. 6): se l'elenco
#        presente ha un altro sha (strumento cambiato, elenco rigenerato dopo l'autorizzazione) -> STOP 4, nulla invocato.
#        --prova stampa lo sha da scrivere nell'autorizzazione.
#   <passi>: sottoinsieme ordinato di A,As,B separato da virgole (A = F1,F2,F3 ombra 0; As = F1,F2,F3 ombra 1;
#            B = F4, terminale: se c'e', e' l'ULTIMO). Modulo: stadio 10 congelato (quello di run-opnd-kut.sh).
#
# Sequenza (--esegui): smoke originale -> scambio originale->stadio10 -> smoke C1 -> per ogni passo: runner, pulizia
# (--distruggi-da), riclassificazione (deve dire NESSUN_NODO), continuita' -> ritorno stadio10->originale -> smoke.
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
# SEQ_FINTO (solo collaudo, test-sequenza-kut.sh): file che ridefinisce le funzioni t_*; uscita SIMULATA: 2 al posto
# di 0, mai 0; ogni riga del diario e la riga finale dicono SIMULATA.
set -u
W=/mnt/linuxulator2/vm/wsl2/linux
C=$W/caldo
umask 022
t_ora()     { /bin/date '+%F %T'; }
T_SMOKE=$C/smoke-modulo.sh; T_CALDO=$C/modulo-caldo.sh; T_RUNNER=$W/run-opnd-kut.sh; T_RESIDUO=$C/vmm-residuo.sh
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

uso() { echo "uso: $0 --prova <cartella nuova> <passi> | --esegui <cartella nuova> <passi> <sha dell'elenco approvato> (passi: A,As,B in quest'ordine, B ultimo)"; exit 4; }
MODO=${1:-}
case "$MODO" in
--prova)  [ $# = 3 ] || uso; SHA_AUT="";;
--esegui) [ $# = 4 ] || uso; SHA_AUT=$4
	echo "$SHA_AUT" | /usr/bin/grep -qx '[0-9a-f]\{64\}' || { [ -n "$SIM" ] && [ "$SHA_AUT" = finto ]; } || uso;;
*) uso;;
esac
SEQ=$2; PASSI=$3
case "$SEQ" in
/mnt/linuxulator2/vm/wsl2/linux/logs/*) ;;
/mnt/linuxulator2/vm/wsl2/linux/collaudi/*) [ -n "$SIM" ] || { echo "STOP: collaudi/ e' solo per il modo finto"; exit 4; };;
*) echo "STOP: la cartella deve stare in $W/logs (ZFS)"; exit 4;;
esac
[ -e "$SEQ" ] && { echo "STOP: $SEQ esiste gia'"; exit 4; }
# passi: solo A, As, B, ciascuno al piu' una volta, in quest'ordine
ord=0; LISTA=""
for p in $(echo "$PASSI" | tr ',' ' '); do
	case "$p" in A) o=1;; As) o=2;; B) o=3;; *) echo "STOP: passo sconosciuto '$p'"; exit 4;; esac
	[ $o -gt $ord ] || { echo "STOP: passi fuori ordine o ripetuti ($PASSI): l'ordine e' A,As,B e B e' l'ultimo"; exit 4; }
	ord=$o; LISTA="$LISTA $p"
done
[ -n "$LISTA" ] || uso
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
diario "SEQUENZA $MODO passi$LISTA in $SEQ"
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
piano_di() { case "$1" in A) echo "--esegui F1,F2,F3";; As) echo "--esegui-ombra F1,F2,F3";; B) echo "--esegui-d F4";; esac; }

if [ "$MODO" = --prova ]; then
	inv smoke-originale t_smoke originale || fine 4 "prova: smoke originale non coerente"
	inv caldo-prova t_caldo --prova originale stadio10 || fine 4 "prova: preflight dello scambio rifiutato"
	for p in $LISTA; do
		set -- $(piano_di $p)
		inv runner-prova-$p t_runner --prova $2 $SEQ/prova-$p
		r=$?; [ $r = 6 ] || [ $r = 0 ] || fine 4 "prova: preflight del runner per $p rc=$r"
	done
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
		case " $TENTATA " in *" $REC_S "*) fine 6 "STOP ($*); vm2 della sessione ancora presente dopo una distruzione gia' tentata: operatore";; esac
		TENTATA="$TENTATA $REC_S"
		inv recupero-distruggi t_residuo --distruggi-da "$REC_S" || fine 6 "STOP ($*); distruzione del recupero fallita"
		inv recupero-riclassifica t_residuo --classifica-ritorno "$REC_S" || fine 6 "STOP ($*); riclassificazione del recupero fallita"
		g=$(ramo "$ULTIMO")
	fi
	case "$g" in
	NESSUN_NODO)
		inv recupero-ritorno t_caldo --esegui stadio10 originale; r=$?
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
inv scambio t_caldo --esegui originale stadio10; r=$?
case $r in
0) ;;
4) fine 4 "scambio rifiutato (rc 4): nulla cambiato";;
5) inv smoke-originale-dopo-scambio-fallito t_smoke originale || fine 6 "scambio fallito (rc 5) e smoke originale non coerente"
   fine 4 "scambio fallito (rc 5), tornato all'originale verificato";;
*) fine 6 "scambio rc=$r: operatore";;
esac
FASE=stadio10
inv smoke-C1 t_smoke stadio10 || recupero nessuna "smoke C1 dello stadio 10 non coerente"
for p in $LISTA; do
	FASE=sessione-$p; S=$SEQ/$p-sessione
	set -- $(piano_di $p)
	inv runner-$p t_runner $1 $2 $S || recupero $S "runner $p rc=$?"
	TENTATA="$TENTATA $S"
	inv pulizia-$p t_residuo --distruggi-da $S || recupero $S "pulizia dopo $p"
	inv riclassifica-$p t_residuo --classifica-ritorno $S || recupero $S "riclassificazione dopo $p"
	g=$(ramo "$ULTIMO"); [ "$g" = NESSUN_NODO ] || recupero $S "dopo la pulizia di $p il ramo e' '$g', non NESSUN_NODO"
	inv continuita-$p t_smoke stadio10 --continuita $S || recupero $S "continuita' dopo $p"
done
FASE=ritorno
inv ritorno t_caldo --esegui stadio10 originale; r=$?
case $r in
0) ;;
5) inv smoke-originale-dopo-ritorno-fallito t_smoke originale || fine 6 "ritorno fallito (rc 5) e smoke originale non coerente"
   fine 4 "ritorno fallito (rc 5) ma tornato all'originale verificato";;
*) fine 6 "ritorno rc=$r: operatore";;
esac
inv smoke-originale-finale t_smoke originale || fine 6 "smoke originale finale non coerente"
fine 0 "sequenza$LISTA completa, host sull'originale"
