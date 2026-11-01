#!/bin/sh
# mutanti-sequenza.sh -- Claude 31/10/2026. Ogni mutante toglie UNA regola di sequenza-kut.sh; test-sequenza-kut.sh
# deve prenderlo (uscita != 0) e ognuno dal caso atteso. Uso: mutanti-sequenza.sh <cartella nuova in nested-work/logs>
# Gira SOLO come utente collaudo (parere Opus sull'incidente, par. 3.1): sudo -u collaudo sh mutanti-sequenza.sh <cartella>
set -u
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/nested-work
O=${1:?cartella}; case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac; [ -e "$O" ] && exit 2; mkdir -p "$O" || exit 2
nok=0; nko=0
mut() {	# mut <nome> <caso che deve prenderlo> <python: trasformazione di t>
	/usr/local/bin/python3 -c "
import sys
t=open('$W/sequenza-kut.sh').read(); u=t
$3
assert u!=t, 'mutazione non applicata'
open('$O/$1.sh','w').write(t)" || { nko=$((nko+1)); echo "  ERRATO  $1: mutazione non applicata"; return; }
	SEQ_SH=$O/$1.sh sh $W/test-sequenza-kut.sh $O/$1 < /dev/null > $O/$1.txt 2>&1; r=$?
	if [ $r != 0 ] && grep -q "ERRATO  $2" $O/$1.txt; then nok=$((nok+1)); echo "  ok      $1 preso da $2 ($(grep -c ERRATO $O/$1.txt) errati)"
	else nko=$((nko+1)); echo "  ERRATO  $1 NON preso da $2 (rc $r; $(grep ERRATO $O/$1.txt | head -2 | tr '\n' ' '))"; fi
}
mut senza_tentata s20-pulizia-A-ko "t=t.replace('fine 6 \"STOP (\$*); vm2 della sessione ancora presente dopo una distruzione gia\' tentata: operatore\";;',':;;')"
mut runner_ko_prosegue s18-A-fail-senza-vm2 "t=t.replace('inv runner-\$p t_runner \$1 \$2 \$S || recupero','inv runner-\$p t_runner \$1 \$2 \$S || true')"
mut senza_nessun_nodo s21-vm2-resta "t=t.replace('[ \"\$g\" = NESSUN_NODO ] || recupero','true || recupero')"
mut successo_simulato_0 s1-completa "t=t.replace('[ -n \"\$SIM\" ] && [ \"\$c\" = 0 ] && c=2','true')"
mut senza_trappole s35-segnale-TERM "t=t.replace('trap \"diario','true \"diario')"
mut operatore_ritorna s24-B-operatore "t=t.replace('\t*)\tfine 6 \"STOP (\$*); ramo','\t*)\tinv recupero-ritorno t_caldo --esegui stadio10 originale; fine 4 \"STOP (\$*); ramo')"
mut B_non_ultimo s4-B-non-ultimo "t=t.replace('[ \$o -gt \$ord ] ||','true ||')"
mut continuita_ignorata s22-continuita-A-ko "t=t.replace('t_smoke stadio10 --continuita \$S || recupero','t_smoke stadio10 --continuita \$S || true')"
mut smoke_finale_ignorato s31-smoke-finale-ko "t=t.replace('inv smoke-originale-finale t_smoke originale || fine 6','inv smoke-originale-finale t_smoke originale || true')"
# MAI un mutante che tolga piu' di una rete (incidente del 31/10: il mutante senza stub ha raggiunto modulo-caldo.sh vero)
mut senza_rete_B s34: "t=t.replace('do eval \"\$x() { echo','do : eval \"\$x() { echo')"
mut senza_rete_A s36 "t=t.replace('T_SMOKE=\$W/trappola-strumento.sh; T_CALDO=\$T_SMOKE; T_RUNNER=\$T_SMOKE; T_RESIDUO=\$T_SMOKE',':')"
mut senza_sha_autorizzazione s44 "t=t.replace('[ \"\$SHA_EL\" = \"\$SHA_AUT\" ] || fine 4','true || fine 4')"
mut senza_verifica_hash s38 "t=t.replace('[ \"\$AS\" = \"\$AH\" ] || fine 4','true || fine 4')"
echo "SUMMARY: $nok presi, $nko non presi"
[ $nko = 0 ]
