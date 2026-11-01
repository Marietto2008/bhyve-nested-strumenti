#!/bin/sh
# collaudi-tutti.sh -- Claude 31/10/2026, parere Opus sull'incidente. L'intera batteria di collaudi e mutanti, SOLO come
# utente collaudo: sudo -u collaudo sh collaudi-tutti.sh <nome del giro>. Uscite in collaudi/<giro>/. Fuori da qui (come
# marietto, e NON a ogni giro: solo dopo un aggiornamento di sudo o di /bin/sh): sonda-h1-sudo.sh.
set -u
. /mnt/linuxulator2/vm/wsl2/fbsd/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/wsl2/fbsd; G=$COLLAUDI/${1:?giro}
[ -e "$G" ] && { echo "$G esiste"; exit 2; }; mkdir -p "$G" || exit 2
T=$W/freebsd-s10-nested; nko=0
s() {	# s <nome> <comando...>
	n=$1; shift; t0=$(date +%s)
	"$@" > "$G/$n.txt" 2>&1 < /dev/null; r=$?
	echo "$n rc=$r ($(( $(date +%s) - t0 )) s): $(grep -E 'SUMMARY|test-verdetti:|errori [0-9]' "$G/$n.txt" | tail -1)"
	[ $r = 0 ] || nko=$((nko+1))
}
s sequenza          sh $W/test-sequenza-kut.sh $G/sequenza
s mutanti-sequenza  sh $W/mutanti-sequenza.sh $G/mutanti-sequenza
s gettone           sh $W/gettone/test-gettone.sh $G/gettone
s vmm-residuo       sh $W/caldo/test-vmm-residuo.sh $G/vmm-residuo
s smoke-stadio9     sh $W/caldo/test-smoke-stadio9.sh $G/smoke-stadio9
s opnd-manifest     sh $W/test-opnd-manifest.sh $G/opnd-manifest
s verdetti          python3 $W/test-verdetti.py $G/verdetti
s ombra             python3 $W/test-ombra.py $G/ombra
s mutanti-verdetto  sh $W/mutanti-verdetto-ombra.sh $G/mutanti-verdetto
s banco-r9c         sh $W/banco-r9c/run.sh $T $G/banco-r9c
s mutanti-r9c       sh $W/banco-r9c/mutanti.sh $T $G/mutanti-r9c
s banco-kut-r3      sh $W/banco-kut-r3/run.sh $W/kut-src-opnd/x86/opnd_test.c.inc $G/banco-kut-r3
s banco-opnd-s10    sh $W/banco-opnd-s10/run.sh $G/banco-opnd-s10
s banco-p3-s11      sh $W/banco-p3-s11/run.sh $G/banco-p3-s11
s banco-r1-s11      sh $W/banco-r1-s11/run.sh $G/banco-r1-s11
s banco-opnd-s11    sh $W/banco-opnd-s11/run.sh $G/banco-opnd-s11
s modulo-caldo      sh $W/caldo/test-modulo-caldo.sh $G/modulo-caldo
s argv              sh $W/caldo/test-argv.sh
s ferma-dtrace      sh $W/test-ferma-dtrace.sh $G/ferma-dtrace
s controllo-azioni  sh $W/test-controllo-azioni.sh $G/controllo-azioni
s gettone-azione   sh $W/gettone/test-vmm-azione.sh $G/gettone-azione
s gettone-lettura  sh $W/gettone/test-vmm-lettura.sh $G/gettone-lettura
s conformita      sh $W/gettone/test-conformita-wrapper.sh $G/conformita
s wsl-verdetto     python3 $W/test-wsl-verdetto.py $G/wsl-verdetto
s analisi-wsl      python3 $W/test-analisi-wsl.py $G/analisi-wsl
s sequenza-wsl     sh $W/test-sequenza-wsl.sh $G/sequenza-wsl
s sequenza-p3      sh $W/test-sequenza-p3.sh $G/sequenza-p3
s p3-verdetto      python3 $W/test-p3-verdetto.py $G/p3-verdetto
# scritture di collaudo nel workspace: il find completo, atteso vuoto fuori da collaudi/
t0=$(date +%s); x=$(find /mnt/linuxulator2/vm/wsl2/fbsd -writable ! -path '/mnt/linuxulator2/vm/wsl2/fbsd/collaudi' ! -path '/mnt/linuxulator2/vm/wsl2/fbsd/collaudi/*' 2>/dev/null | head -20)
if [ -z "$x" ]; then echo "scritture rc=0 ($(( $(date +%s) - t0 )) s): collaudo non puo' scrivere nulla fuori da collaudi/"; else nko=$((nko+1)); echo "scritture rc=1: scrivibili da collaudo: $(echo "$x" | tr '\n' ' ')"; fi
echo "GIRO $1: $nko suite fallite"
[ $nko = 0 ]
