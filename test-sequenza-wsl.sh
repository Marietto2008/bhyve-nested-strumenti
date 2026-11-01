#!/bin/sh
# test-sequenza-wsl.sh -- Claude 01/11/2026. Collaudo di sequenza-wsl.sh (la campagna Hyper-V/WSL2) su un host SIMULATO,
# con lo STESSO finto di test-sequenza-kut.sh (runner adattato: <modo> <cartella>). Si confronta la sequenza ESATTA delle
# invocazioni, l'esito e il diario. Gira SOLO come utente collaudo: sudo -u collaudo sh test-sequenza-wsl.sh <cartella>
set -u
. /mnt/linuxulator2/vm/wsl2/fbsd/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/wsl2/fbsd
O=${1:?cartella}
case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste gia'"; exit 2; }
mkdir -p "$O" || exit 2
SEQ_SH=${SEQ_SH:-$W/sequenza-wsl.sh}
printf '%s\n' '# elenco del collaudo' "finto $W/run-wsl-corsa.sh" > "$O/approvati.sha256"
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
	[ "$1" = --prova ] && { [ "$(modulo)" = "${3:-stadio10}" ] && { echo "PROVA ok"; return 0; }; echo "${3:-stadio10} non caricato"; return 6; }
	[ "$(modulo)" = "${3:-stadio10}" ] || { echo "STOP"; return 4; }
	mkdir -p "$2"; echo "${2##*/}" >| "$VS/vm2"			# la VM della corsa (nel finto lo stato si chiama vm2)
	[ -e "$VS/vm_sparisce" ] && : >| "$VS/vm2"			# spegnimento: bhyve ha gia' tolto il nodo
	[ -e "$VS/rcpost.$FT_K.$FT_c" ] && { echo "FAIL dopo aver creato la VM"; return $(cat "$VS/rcpost.$FT_K.$FT_c"); }
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

caso() {	# caso <nome> <uscita attesa> <modo> <N> <ombra> [sha]; iniezioni in INI
	N=$1; A=$2; M=$3; NC=$4; OM=$5; VS=$O/$N; mkdir -p "$VS"; : >| "$VS/eventi"; echo "${MOD0:-originale}" >| "$VS/modulo"
	for i in ${INI:-}; do case "$i" in *=*) echo "${i#*=}" >| "$VS/${i%%=*}";; *) : >| "$VS/$i";; esac; done
	VS=$VS SEQ_FINTO=$O/finto.sh sh "$SEQ_SH" "$M" "$VS/seq" "$NC" "$OM" ${SHA_ARG-$( [ "$M" = --esegui ] && echo finto)} ${STADIO_ARG:-} > "$VS/out" 2>&1; r=$?
	[ $r = $A ] && ok "$N uscita $r" || no "$N uscita $r, attesa $A ($(tail -1 $VS/out))"
}
attesi() {
	e=$(tr '\n' ' ' < "$VS/eventi" | sed 's/ $//')
	[ "$e" = "$*" ] && ok "$N invocazioni esatte" || { no "$N invocazioni"; echo "          attese: $*"; echo "          avute:  $e"; }
}
ANDATA="smoke_originale caldo_--esegui_originale_stadio10 smoke_stadio10"
RITORNO="caldo_--esegui_stadio10_originale smoke_originale"
CON="runner_--esegui_corsa%d_stadio10 residuo_--classifica-ritorno_corsa%d residuo_--distruggi-da_corsa%d residuo_--classifica-ritorno_corsa%d smoke_stadio10_--continuita_corsa%d"
SENZA="runner_--esegui_corsa%d_stadio10 residuo_--classifica-ritorno_corsa%d smoke_stadio10_--continuita_corsa%d"
c() { printf "$CON" $1 $1 $1 $1 $1; }
s() { printf "$SENZA" $1 $1 $1; }

echo "W1: campagna completa"
caso w1-due-corse-vm-resta 2 --esegui 2 0; attesi $ANDATA $(c 1) $(c 2) $RITORNO
grep -q 'ESITO 2: campagna completa su stadio10: 2 corse, ombra 0' "$VS/out" && ok "w1: successo SIMULATO esce 2" || no "w1: $(tail -1 $VS/out)"
INI=vm_sparisce caso w2-vm-sparisce 2 --esegui 3 0; attesi $ANDATA $(s 1) $(s 2) $(s 3) $RITORNO
caso w3-ombra 2 --esegui 1 1; attesi $ANDATA $(c 1 | sed 's/runner_--esegui_/runner_--esegui-ombra_/') $RITORNO
echo "W2: argomenti rifiutati prima di qualunque invocazione"
for x in "w4-zero-corse:0:0" "w5-troppe:13:0" "w6-ombra-2:1:2" "w7-corse-non-numero:x:0"; do
	n=${x%%:*}; y=${x#*:}; caso $n 4 --esegui ${y%%:*} ${y#*:}; attesi
done
SHA_ARG="" caso w8-senza-sha 4 --esegui 1 0; attesi
SHA_ARG="$(printf 'e%.0s' $(seq 64))" caso w9-sha-diverso 4 --esegui 1 0; attesi
echo "W3: STOP dopo lo scambio -> solo recupero e ritorno"
INI="rc.runner_--esegui_corsa1_stadio10.1=1" caso w10-corsa-fail 4 --esegui 2 0
attesi $ANDATA runner_--esegui_corsa1_stadio10 residuo_--classifica-ritorno_corsa1 $RITORNO
INI="rcpost.runner_--esegui_corsa2_stadio10.1=1" caso w11-corsa2-fail-con-vm 4 --esegui 3 0
attesi $ANDATA $(c 1) runner_--esegui_corsa2_stadio10 residuo_--classifica-ritorno_corsa2 residuo_--distruggi-da_corsa2 residuo_--classifica-ritorno_corsa2 $RITORNO
INI="rc.residuo_--distruggi-da_corsa1.1=4" caso w12-pulizia-ko 6 --esegui 2 0
attesi $ANDATA runner_--esegui_corsa1_stadio10 residuo_--classifica-ritorno_corsa1 residuo_--distruggi-da_corsa1 residuo_--classifica-ritorno_corsa1
INI="ramo.residuo_--classifica-ritorno_corsa1.1=OPERATORE ramo.residuo_--classifica-ritorno_corsa1.2=OPERATORE" caso w13-classifica-operatore 6 --esegui 2 0
attesi $ANDATA runner_--esegui_corsa1_stadio10 residuo_--classifica-ritorno_corsa1 residuo_--classifica-ritorno_corsa1
INI="rc.smoke_stadio10_--continuita_corsa1.1=4" caso w14-continuita-ko 4 --esegui 2 0
attesi $ANDATA $(c 1) residuo_--classifica-ritorno_corsa1 $RITORNO
INI="rc.smoke_stadio10.1=4" caso w15-C1-ko 4 --esegui 2 0; attesi $ANDATA residuo_--classifica-ritorno_nessuna $RITORNO
echo "W4: --prova"
caso w16-prova 2 --prova 3 1; attesi smoke_originale caldo_--prova_originale_stadio10 runner_--prova_prova-corsa_stadio10
grep -q "sha dell'elenco approvato, da scrivere nel testo dell'autorizzazione: finto" "$VS/out" && ok "w16: la prova stampa lo sha" || no "w16: sha non stampato"
echo "W6: stadio 11 (parere #172): stessa sequenza, lo stadio in ogni invocazione; stadio non valido rifiutato"
STADIO_ARG=stadio11 caso w17-stadio11 2 --esegui 1 0
attesi smoke_originale caldo_--esegui_originale_stadio11 smoke_stadio11 runner_--esegui_corsa1_stadio11 residuo_--classifica-ritorno_corsa1 residuo_--distruggi-da_corsa1 residuo_--classifica-ritorno_corsa1 smoke_stadio11_--continuita_corsa1 caldo_--esegui_stadio11_originale smoke_originale
grep -q 'ESITO 2: campagna completa su stadio11: 1 corse, ombra 0' "$VS/out" && ok "w17: esito dice stadio11" || no "w17: $(tail -1 $VS/out)"
INI="rc.runner_--esegui_corsa1_stadio11.1=1" STADIO_ARG=stadio11 caso w18-stadio11-corsa-fail 4 --esegui 2 0
attesi smoke_originale caldo_--esegui_originale_stadio11 smoke_stadio11 runner_--esegui_corsa1_stadio11 residuo_--classifica-ritorno_corsa1 caldo_--esegui_stadio11_originale smoke_originale
STADIO_ARG=stadio12 caso w19-stadio-ignoto 4 --esegui 1 0; attesi
STADIO_ARG=stadio11 caso w20-prova-stadio11 2 --prova 1 0; attesi smoke_originale caldo_--prova_originale_stadio11 runner_--prova_prova-corsa_stadio11
STADIO_ARG="stadio11 extra" caso w21-argomento-in-piu 4 --esegui 1 0; attesi
echo "W5: nessuna trappola scattata"
x=$(ls $O/w*/seq/TRAPPOLE.txt 2>/dev/null); [ -z "$x" ] && ok "nessuna trappola scattata" || no "TRAPPOLE: $x"
echo "SUMMARY: $nok ok, $nf errati"
[ $nf = 0 ]
