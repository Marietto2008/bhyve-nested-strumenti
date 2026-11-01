#!/bin/sh
# test-sequenza-kut.sh -- Claude 31/10/2026, riesame Opus (sequenza stadio 10) par. 3. Collaudo di sequenza-kut.sh su
# un host SIMULATO: modulo caricato e vm2 in file, gli strumenti (smoke, scambio, runner, residuo) ridefiniti via
# SEQ_FINTO con un modello minimo del loro comportamento. Un'iniezione rc.<chiave>.<occorrenza> forza il codice
# d'uscita di UNA invocazione. Si confronta la sequenza ESATTA delle invocazioni, l'esito e il diario.
# Nessun sudo, nessun sysctl, nessuna VM. Gira SOLO come utente collaudo (parere Opus sull'incidente, par. 3.1):
#   sudo -u collaudo sh test-sequenza-kut.sh <cartella nuova in nested-work/collaudi>
set -u
. /mnt/linuxulator2/vm/wsl2/fbsd/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/wsl2/fbsd
O=${1:?cartella}
case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste gia'"; exit 2; }
mkdir -p "$O" || exit 2
SEQ_SH=${SEQ_SH:-$W/sequenza-kut.sh}
printf '%s\n' '# elenco del collaudo' "finto $W/run-opnd-kut.sh" "finto $W/caldo/modulo-caldo.sh" > "$O/approvati.sha256"
SEQ_APPROVATI=$O/approvati.sha256; export SEQ_APPROVATI
nf=0; nok=0
ok() { nok=$((nok+1)); echo "  ok      $*"; }
no() { nf=$((nf+1)); echo "  ERRATO  $*"; }
cat > "$O/finto.sh" <<'FINE_FINTO_SEQ_OPUS'
t_ora() { echo "2026-10-31 00:00:00"; }
t_sha() { echo finto; }
evento() {	# chiave = tipo + argomenti (i percorsi ridotti al nome); occorrenza contata per chiave
	FT_K=""; for FT_a in "$@"; do case "$FT_a" in /*) FT_a=${FT_a##*/};; esac; FT_K="${FT_K:+${FT_K}_}$FT_a"; done
	FT_c=$(( $(cat "$VS/cnt.$FT_K" 2>/dev/null || echo 0) + 1 )); echo $FT_c >| "$VS/cnt.$FT_K"
	echo "$FT_K" >> "$VS/eventi"
	FT_INI=""; [ -e "$VS/rc.$FT_K.$FT_c" ] && FT_INI=$(cat "$VS/rc.$FT_K.$FT_c")
	[ -e "$VS/lento.$FT_K.$FT_c" ] && { : > "$VS/pronto"; sleep 2; }
	return 0
}
iniettato() { [ -n "$FT_INI" ] && { [ -e "$VS/stato.$FT_K.$FT_c" ] && cat "$VS/stato.$FT_K.$FT_c" >| "$VS/modulo"; echo "iniettato rc $FT_INI"; return 0; }; return 1; }
modulo() { cat "$VS/modulo"; }
t_smoke() {
	evento smoke "$@"; iniettato && return $FT_INI
	[ "$(modulo)" = "$1" ] && [ ! -s "$VS/vm2" ] && { echo "SMOKE $1: COERENTE"; return 0; }
	echo "SMOKE $1: STOP"; return 4
}
t_caldo() {
	evento caldo "$@"; iniettato && return $FT_INI
	[ "$1" = --prova ] && { echo "PROVA"; return 0; }
	[ "$(modulo)" = "$2" ] && [ ! -s "$VS/vm2" ] || { echo "ESITO 4"; return 4; }
	echo "$3" >| "$VS/modulo"; echo "ESITO 0"; return 0
}
t_runner() {
	evento runner "$@"; iniettato && return $FT_INI
	[ "$1" = --prova ] && { [ "$(modulo)" = stadio10 ] && { echo "PROVA ok"; return 0; }; echo "stadio 10 non caricato"; return 6; }
	[ "$(modulo)" = stadio10 ] || { echo "STOP"; return 4; }
	mkdir -p "$3"; echo "${3##*/}" >| "$VS/vm2"
	[ -e "$VS/rcpost.$FT_K.$FT_c" ] && { echo "FAIL dopo aver creato vm2"; return $(cat "$VS/rcpost.$FT_K.$FT_c"); }
	echo "PASS"; return 0
}
t_residuo() {
	evento residuo "$@"; iniettato && return $FT_INI
	FT_s=${2##*/}
	case "$1" in
	--classifica-ritorno)
		if [ -e "$VS/ramo.$FT_K.$FT_c" ]; then echo "RAMO=$(cat "$VS/ramo.$FT_K.$FT_c") iniettato"; return 0; fi
		if [ -s "$VS/vm2" ]; then
			[ "$(cat "$VS/vm2")" = "$FT_s" ] && { echo "RAMO=NODO_DELLA_SESSIONE vm2 di $FT_s"; return 0; }
			echo "RAMO=OPERATORE vm2 non attribuibile"; return 0
		fi
		[ "$(modulo)" = originale ] && { echo "RAMO=GIA_RIPRISTINATO vuoto"; return 0; }
		echo "RAMO=NESSUN_NODO vuoto"; return 0;;
	--distruggi-da)
		[ -s "$VS/vm2" ] && [ "$(cat "$VS/vm2")" = "$FT_s" ] || { echo "RIFIUTO"; return 4; }
		[ -e "$VS/vm2_resta" ] || { cat "$VS/vm2" >> "$VS/distrutte"; : >| "$VS/vm2"; }
		echo "ESITO 0"; return 0;;
	esac
	echo "uso"; return 4
}
FINE_FINTO_SEQ_OPUS

# caso <nome> <uscita attesa> <modo> <passi> -- iniezioni: INI="file[=contenuto] ..." ; stato iniziale MOD0
caso() {
	N=$1; A=$2; M=$3; P=$4; VS=$O/$N; mkdir -p "$VS"; : >| "$VS/eventi"; echo "${MOD0:-originale}" >| "$VS/modulo"
	for i in ${INI:-}; do case "$i" in *=*) echo "${i#*=}" >| "$VS/${i%%=*}";; *) : >| "$VS/$i";; esac; done
	VS=$VS SEQ_FINTO=$O/finto.sh sh "$SEQ_SH" "$M" "$VS/seq" "$P" ${SHA_ARG-$( [ "$M" = --esegui ] && echo finto)} > "$VS/out" 2>&1; r=$?
	[ $r = $A ] && ok "$N uscita $r" || no "$N uscita $r, attesa $A ($(tail -1 $VS/out))"
}
# attesi <eventi separati da spazi>: la sequenza ESATTA delle invocazioni
attesi() {
	e=$(tr '\n' ' ' < "$VS/eventi" | sed 's/ $//')
	[ "$e" = "$*" ] && ok "$N invocazioni esatte" || { no "$N invocazioni"; echo "          attese: $*"; echo "          avute:  $e"; }
}
# diario coerente: un INIZIO e un FINE rc=... per invocazione, numerati, e l'ESITO in fondo
diario_ok() {
	d=$VS/seq/DIARIO.txt; ne=$(grep -c '' "$VS/eventi"); ni=$(grep -c ' INIZIO ' "$d"); nfi=$(grep -c ' FINE [0-9]* .* rc=[0-9]* ' "$d")
	[ "$ni" = "$ne" ] && [ "$nfi" = "$ne" ] && ok "$N diario: $ne INIZIO e $ne FINE con rc" || no "$N diario: eventi $ne, INIZIO $ni, FINE $nfi"
	tail -1 "$d" | grep -q " ESITO ${1:-[0-9]*}: " && ok "$N diario chiuso dall'ESITO" || no "$N ultima riga del diario: $(tail -1 $d)"
	grep -vq ' SIMULATA ' "$d" && no "$N righe del diario senza SIMULATA" || ok "$N ogni riga del diario dice SIMULATA"
}
OK_A="runner_--esegui_F1,F2,F3_A-sessione residuo_--distruggi-da_A-sessione residuo_--classifica-ritorno_A-sessione smoke_stadio10_--continuita_A-sessione"
OK_AS="runner_--esegui-ombra_F1,F2,F3_As-sessione residuo_--distruggi-da_As-sessione residuo_--classifica-ritorno_As-sessione smoke_stadio10_--continuita_As-sessione"
OK_B="runner_--esegui-d_F4_B-sessione residuo_--distruggi-da_B-sessione residuo_--classifica-ritorno_B-sessione smoke_stadio10_--continuita_B-sessione"
ANDATA="smoke_originale caldo_--esegui_originale_stadio10 smoke_stadio10"
RITORNO="caldo_--esegui_stadio10_originale smoke_originale"

echo "S1: sequenza completa"
caso s1-completa 2 --esegui A,As,B; attesi $ANDATA $OK_A $OK_AS $OK_B $RITORNO; diario_ok 2
grep -q 'ESITO 2: .*completa' "$VS/out" && ok "s1: successo SIMULATO esce 2, mai 0" || no "s1: $(tail -1 $VS/out)"
[ "$(cat $VS/modulo)" = originale ] && ok "s1: host simulato sull'originale" || no "s1: modulo $(cat $VS/modulo)"
caso s2-solo-A 2 --esegui A; attesi $ANDATA $OK_A $RITORNO; diario_ok 2
caso s3-solo-B 2 --esegui B; attesi $ANDATA $OK_B $RITORNO

echo "S2: argomenti rifiutati prima di qualunque invocazione"
for x in "s4-B-non-ultimo:B,A" "s5-ripetuto:A,A" "s6-fuori-ordine:As,A" "s7-sconosciuto:A,F4" "s8-vuoto:,"; do
	caso ${x%%:*} 4 --esegui "${x#*:}"; attesi
done
caso s9-modo 4 --vai A; attesi
VS=$O/s10-cartella-esistente; mkdir -p $VS/seq; : >| $VS/eventi; echo originale >| $VS/modulo
VS=$VS SEQ_FINTO=$O/finto.sh sh "$SEQ_SH" --esegui "$VS/seq" A finto > "$VS/out" 2>&1; r=$?
[ $r = 4 ] && [ ! -s $VS/eventi ] && ok "s10: cartella esistente rifiutata (4), nessuna invocazione" || no "s10: rc=$r $(cat $VS/eventi)"
VS=$O/s11-fuori-zfs; mkdir -p $VS; : >| $VS/eventi
VS=$VS SEQ_FINTO=$O/finto.sh sh "$SEQ_SH" --esegui /tmp/seq-x A finto > "$VS/out" 2>&1; r=$?
[ $r = 4 ] && [ ! -e /tmp/seq-x ] && ok "s11: cartella fuori da logs rifiutata (4)" || no "s11: rc=$r"

echo "S2b: lo sha dell'autorizzazione (parere Opus sulla separazione par. 6)"
SHA_ARG="" caso s42-senza-sha 4 --esegui A; attesi
SHA_ARG="abc" caso s43-sha-malformato 4 --esegui A; attesi
SHA_ARG="$(printf 'e%.0s' $(seq 64))" caso s44-sha-diverso 4 --esegui A; attesi
grep -q "non e' quello dell'autorizzazione" "$VS/out" && ok "s44: motivo" || no "s44: $(tail -1 $VS/out)"
grep -q "sha dell'elenco = sha dell'autorizzazione" $O/s1-completa/seq/DIARIO.txt && ok "s1: sha dell'autorizzazione verificato nel diario" || no "s1: verifica dello sha non nel diario"
grep -q "sha dell'elenco approvato, da scrivere nel testo dell'autorizzazione: finto" $O/s32-prova/out 2>/dev/null && ok "s32: la prova stampa lo sha da autorizzare" || echo "  (s32 controllato dopo S6)"
echo "S3: prima dello scambio"
MOD0=stadio10 caso s12-host-non-originale 4 --esegui A; attesi smoke_originale; diario_ok 4
INI="rc.caldo_--esegui_originale_stadio10.1=4" caso s13-scambio-rifiutato 4 --esegui A; attesi smoke_originale caldo_--esegui_originale_stadio10
INI="rc.caldo_--esegui_originale_stadio10.1=5" caso s14-scambio-fallito-tornato 4 --esegui A; attesi smoke_originale caldo_--esegui_originale_stadio10 smoke_originale
INI="rc.caldo_--esegui_originale_stadio10.1=6" caso s15-scambio-operatore 6 --esegui A; attesi smoke_originale caldo_--esegui_originale_stadio10
INI="rc.caldo_--esegui_originale_stadio10.1=5 rc.smoke_originale.2=4" caso s16-scambio-fallito-smoke-ko 6 --esegui A; attesi smoke_originale caldo_--esegui_originale_stadio10 smoke_originale

echo "S4: STOP dopo lo scambio -> solo recupero e ritorno"
REC_VUOTO="residuo_--classifica-ritorno_nessuna"
INI="rc.smoke_stadio10.1=4" caso s17-C1-ko 4 --esegui A,As,B; attesi $ANDATA $REC_VUOTO $RITORNO; diario_ok 4
grep -q 'STOP: smoke C1' "$VS/seq/DIARIO.txt" && ok "s17: motivo nel diario" || no "s17: motivo"
INI="rc.runner_--esegui_F1,F2,F3_A-sessione.1=1" caso s18-A-fail-senza-vm2 4 --esegui A,As,B
attesi $ANDATA runner_--esegui_F1,F2,F3_A-sessione residuo_--classifica-ritorno_A-sessione $RITORNO
# runner fallito DOPO aver creato vm2: la distruzione del recupero e' ammessa UNA volta
INI="rcpost.runner_--esegui_F1,F2,F3_A-sessione.1=1" caso s19-A-fail-con-vm2 4 --esegui A,As,B
attesi $ANDATA runner_--esegui_F1,F2,F3_A-sessione residuo_--classifica-ritorno_A-sessione residuo_--distruggi-da_A-sessione residuo_--classifica-ritorno_A-sessione $RITORNO
INI="rc.residuo_--distruggi-da_A-sessione.1=4" caso s20-pulizia-A-ko 6 --esegui A,As,B
attesi $ANDATA runner_--esegui_F1,F2,F3_A-sessione residuo_--distruggi-da_A-sessione residuo_--classifica-ritorno_A-sessione
grep -q "distruzione gia' tentata" "$VS/out" && ok "s20: nessun secondo --distruggi-da (regola: niente ripetizioni)" || no "s20: $(tail -1 $VS/out)"
INI="vm2_resta" caso s21-vm2-resta 6 --esegui A
attesi $ANDATA runner_--esegui_F1,F2,F3_A-sessione residuo_--distruggi-da_A-sessione residuo_--classifica-ritorno_A-sessione residuo_--classifica-ritorno_A-sessione
INI="rc.smoke_stadio10_--continuita_A-sessione.1=4" caso s22-continuita-A-ko 4 --esegui A,As,B
attesi $ANDATA $OK_A residuo_--classifica-ritorno_A-sessione $RITORNO
INI="rc.runner_--esegui-ombra_F1,F2,F3_As-sessione.1=5" caso s23-As-inconcl 4 --esegui A,As,B
attesi $ANDATA $OK_A runner_--esegui-ombra_F1,F2,F3_As-sessione residuo_--classifica-ritorno_As-sessione $RITORNO
INI="rc.runner_--esegui-d_F4_B-sessione.1=6 ramo.residuo_--classifica-ritorno_B-sessione.1=OPERATORE" caso s24-B-operatore 6 --esegui A,As,B
attesi $ANDATA $OK_A $OK_AS runner_--esegui-d_F4_B-sessione residuo_--classifica-ritorno_B-sessione
INI="ramo.residuo_--classifica-ritorno_A-sessione.1=EMERGENZA ramo.residuo_--classifica-ritorno_A-sessione.2=EMERGENZA" caso s25-riclassifica-emergenza 6 --esegui A,As
attesi $ANDATA runner_--esegui_F1,F2,F3_A-sessione residuo_--distruggi-da_A-sessione residuo_--classifica-ritorno_A-sessione residuo_--classifica-ritorno_A-sessione
INI="rc.residuo_--classifica-ritorno_A-sessione.1=4" caso s26-riclassifica-rc4 4 --esegui A
attesi $ANDATA runner_--esegui_F1,F2,F3_A-sessione residuo_--distruggi-da_A-sessione residuo_--classifica-ritorno_A-sessione residuo_--classifica-ritorno_A-sessione $RITORNO
INI="rc.residuo_--classifica-ritorno_nessuna.1=4 rc.smoke_stadio10.1=4" caso s27-classifica-recupero-ko 6 --esegui A
attesi $ANDATA $REC_VUOTO
INI="rc.smoke_stadio10.1=4 rc.caldo_--esegui_stadio10_originale.1=6" caso s28-ritorno-recupero-ko 6 --esegui A
attesi $ANDATA $REC_VUOTO caldo_--esegui_stadio10_originale

echo "S5: il ritorno finale"
INI="rc.caldo_--esegui_stadio10_originale.1=5 stato.caldo_--esegui_stadio10_originale.1=originale" caso s29-ritorno-fallito-tornato 4 --esegui A; attesi $ANDATA $OK_A caldo_--esegui_stadio10_originale smoke_originale
INI="rc.caldo_--esegui_stadio10_originale.1=6" caso s30-ritorno-operatore 6 --esegui A; attesi $ANDATA $OK_A caldo_--esegui_stadio10_originale
INI="rc.smoke_originale.2=4" caso s31-smoke-finale-ko 6 --esegui A; attesi $ANDATA $OK_A $RITORNO

echo "S6: --prova: sola lettura"
caso s32-prova 2 --prova A,As,B
attesi smoke_originale caldo_--prova_originale_stadio10 runner_--prova_F1,F2,F3_prova-A runner_--prova_F1,F2,F3_prova-As runner_--prova_F4_prova-B
[ "$(cat $VS/modulo)" = originale ] && [ ! -s $VS/vm2 ] && ok "s32: stato invariato" || no "s32: stato cambiato"
grep -q "sha dell'elenco approvato, da scrivere nel testo dell'autorizzazione: finto" $O/s32-prova/out && ok "s32: la prova stampa lo sha da autorizzare" || no "s32: sha non stampato"
INI="rc.runner_--prova_F1,F2,F3_prova-A.1=4" caso s33-prova-runner-rifiuta 4 --prova A; attesi smoke_originale caldo_--prova_originale_stadio10 runner_--prova_F1,F2,F3_prova-A

echo "S7: le reti contro lo strumento vero (incidente del 31/10)"
# s34, rete B: il finto senza t_caldo (costruito bene: tolta SOLO la funzione, il resto del finto intatto)
awk '/^t_caldo\(\) \{/{salta=1} !salta{print} salta&&/^\}/{salta=0}' "$O/finto.sh" > "$O/finto-senza-caldo.sh"
grep -q '^t_caldo' "$O/finto-senza-caldo.sh" && no "s34: t_caldo ancora nel finto" || ok "s34: finto senza t_caldo"
for f in t_smoke t_runner t_residuo; do grep -q "^$f()" "$O/finto-senza-caldo.sh" && ok "s34: $f ancora nel finto" || no "s34: $f perso"; done
VS=$O/s34-senza-caldo; mkdir -p $VS; : >| $VS/eventi; echo originale >| $VS/modulo
VS=$VS SEQ_FINTO=$O/finto-senza-caldo.sh sh "$SEQ_SH" --esegui "$VS/seq" A finto > "$VS/out" 2>&1; r=$?
[ $r = 6 ] && grep -q 'SIMULATA: t_caldo non ridefinita' "$VS/seq/"*-scambio.txt && ok "s34: t_caldo non ridefinita -> rifiuto simulato (6)" || no "s34: rc=$r $(tail -1 $VS/out)"
[ ! -e "$VS/seq/TRAPPOLE.txt" ] && ok "s34: trappola NON scattata (la rete B regge)" || no "s34: TRAPPOLA scattata: $(cat $VS/seq/TRAPPOLE.txt | tr '\n' ' ')"
# s36, rete A: in modo finto i percorsi degli strumenti puntano alla TRAPPOLA (parere Opus par. 3.3)
printf '%s\n' '. "$(dirname "$SEQ_FINTO")/finto.sh"' 't_smoke() { echo "T $T_SMOKE $T_CALDO $T_RUNNER $T_RESIDUO"; return 4; }' > "$O/finto-percorsi.sh"
VS=$O/s36-percorsi; mkdir -p $VS; : >| $VS/eventi; echo originale >| $VS/modulo
VS=$VS SEQ_FINTO=$O/finto-percorsi.sh sh "$SEQ_SH" --esegui "$VS/seq" A finto > "$VS/out" 2>&1
x=$(sed -n 's/^T //p' "$VS/seq/01-smoke-originale.txt")
TR=$W/trappola-strumento.sh
[ "$x" = "$TR $TR $TR $TR" ] && ok "s36: i 4 strumenti puntano alla trappola" || no "s36: percorsi '$x'"
# s36b: la trappola registra e non agisce (invocata direttamente come farebbe una t_* vera)
SEQ_TRAPPOLE=$O/s36b-trappole.txt sh "$TR" --esegui originale stadio10 > $O/s36b.out 2>&1; r=$?
[ $r = 99 ] && grep -qx "TRAPPOLA --esegui originale stadio10 (utente collaudo)" $O/s36b-trappole.txt && ok "s36b: trappola scattata: registrata, uscita 99" || no "s36b: rc=$r $(cat $O/s36b-trappole.txt 2>/dev/null)"
# s37, guardia degli strumenti veri (parere Opus par. 3.3): si verifica il MOTIVO. Come utente collaudo nessuno di
# questi comandi potrebbe comunque agire (niente sudo); la guardia scatta prima di qualunque lettura.
SEQ_FINTO=/var/empty/x sh $W/caldo/modulo-caldo.sh --prova originale stadio10 < /dev/null > $O/s37-caldo.txt 2>&1; r=$?
[ $r = 4 ] && grep -q "GUARDIA: variabile di collaudo nell'ambiente (SEQ_FINTO )" $O/s37-caldo.txt && ok "s37: modulo-caldo.sh vero: guardia per SEQ_FINTO (4)" || no "s37: modulo-caldo rc=$r $(head -2 $O/s37-caldo.txt | tr '\n' ' ')"
sh $W/caldo/modulo-caldo.sh --prova originale stadio10 < /dev/null > $O/s37-caldo-utente.txt 2>&1; r=$?
[ $r = 4 ] && grep -q "GUARDIA: utente collaudo" $O/s37-caldo-utente.txt && ok "s37: modulo-caldo.sh vero: guardia per l'utente collaudo (4)" || no "s37: modulo-caldo utente rc=$r $(head -2 $O/s37-caldo-utente.txt | tr '\n' ' ')"
for m in "--distruggi-da $O/non-esiste" "--distruggi vm2 1 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; do
	SEQ_FINTO=/var/empty/x VR_DIARIO=$O/s37-diario sh $W/caldo/vmm-residuo.sh ${m} < /dev/null > $O/s37-residuo.txt 2>&1; r=$?
	[ $r = 4 ] && grep -q "GUARDIA: variabile di collaudo" $O/s37-residuo.txt && grep -q "RIFIUTO: guardia" $O/s37-residuo.txt && ! grep -q '^RAMO=' $O/s37-residuo.txt && ok "s37: vmm-residuo.sh vero ${m%% *}: guardia PRIMA della classificazione (4)" || no "s37: residuo ${m%% *} rc=$r $(head -3 $O/s37-residuo.txt | tr '\n' ' ')"
done
SEQ_FINTO=/var/empty/x sh $W/run-opnd-kut.sh --prova F1 $O/s37-runner < /dev/null > $O/s37-runner.txt 2>&1; r=$?
[ $r = 4 ] && grep -q "GUARDIA: variabile di collaudo" $O/s37-runner.txt && ok "s37: run-opnd-kut.sh vero: guardia (4)" || no "s37: runner rc=$r $(head -2 $O/s37-runner.txt | tr '\n' ' ')"
# s38-s41: strumenti approvati VERIFICATI (parere Opus par. 4.2), prima di qualunque invocazione
printf '%s\n' "finto $W/run-opnd-kut.sh" "deadbeef $W/caldo/modulo-caldo.sh" > $O/approvati-diverso.sha256
: > $O/approvati-vuoto.sha256; printf '%s\n' '# solo commenti' > $O/approvati-commenti.sha256
for x in "s38-hash-diverso:$O/approvati-diverso.sha256:diverso da quello approvato" "s39-elenco-assente:$O/non-esiste.sha256:approvati assente" "s40-elenco-vuoto:$O/approvati-vuoto.sha256:approvati vuoto" "s41-solo-commenti:$O/approvati-commenti.sha256:approvati vuoto"; do
	N=${x%%:*}; y=${x#*:}; L=${y%%:*}; m=${y#*:}; VS=$O/$N; mkdir -p $VS; : >| $VS/eventi; echo originale >| $VS/modulo
	VS=$VS SEQ_FINTO=$O/finto.sh SEQ_APPROVATI=$L sh "$SEQ_SH" --esegui "$VS/seq" A finto > "$VS/out" 2>&1; r=$?
	[ $r = 4 ] && [ ! -s $VS/eventi ] && grep -q "$m" "$VS/out" && ok "$N: STOP 4 prima di qualunque invocazione ($m)" || no "$N: rc=$r eventi '$(cat $VS/eventi | tr '\n' ' ')' $(tail -1 $VS/out)"
done
grep -q "approvato finto $W/run-opnd-kut.sh" $O/s1-completa/seq/DIARIO.txt && grep -q 'strumenti approvati: 2' $O/s1-completa/seq/DIARIO.txt && ok "s1: approvati verificati e scritti nel diario" || no "s1: approvati non nel diario"

echo "S8: segnali VERI durante un'invocazione in primo piano"
for x in TERM:143 INT:130 HUP:129; do
	sg=${x%%:*}; N=s35-segnale-$sg; VS=$O/$N; mkdir -p $VS; : >| $VS/eventi; echo originale >| $VS/modulo; : >| "$VS/lento.runner_--esegui_F1,F2,F3_A-sessione.1"
	r=$(VS=$VS SEQ_FINTO=$O/finto.sh /usr/local/bin/python3 -c '
import os, signal, subprocess, sys, time
vs, seq, sh, sg = sys.argv[1:5]
p = subprocess.Popen(["/bin/sh", sh, "--esegui", seq, "A,As", "finto"], stdout=open(vs + "/out", "w"), stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
t0 = time.monotonic()
while not os.path.exists(vs + "/pronto") and p.poll() is None and time.monotonic() - t0 < 10: time.sleep(0.05)
p.send_signal(getattr(signal, "SIG" + sg))
rc = p.wait(timeout=30)
print(128 - rc if rc < 0 else rc)' "$VS" "$VS/seq" "$SEQ_SH" $sg)
	[ $r = ${x#*:} ] && ok "$N uscita $r" || no "$N uscita $r, attesa ${x#*:}"
	attesi $ANDATA runner_--esegui_F1,F2,F3_A-sessione
	grep -q "INTERROTTA da SIG$sg (fase sessione-A, ultima invocazione 4)" "$VS/seq/DIARIO.txt" && ok "$N diario: interrotta, fase e invocazione" || no "$N diario: $(tail -2 $VS/seq/DIARIO.txt | tr '\n' ' ')"
done

echo "S9: lo script vero non e' mai stato invocato su strumenti veri"
x=$(grep -l 'SIMULATA: t_' $O/s*/seq/*.txt 2>/dev/null | grep -v /s34-)
[ -z "$x" ] && ok "nessuna funzione non ridefinita usata fuori da s34" || no "funzioni non ridefinite usate: $x"
x=$(ls $O/s*/seq/TRAPPOLE.txt 2>/dev/null)
[ -z "$x" ] && ok "nessuna trappola scattata in nessun caso" || no "TRAPPOLE scattate: $x"
echo "SUMMARY: $nok ok, $nf errati"
[ $nf = 0 ]
