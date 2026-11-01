#!/bin/sh
# test-controllo-azioni.sh -- Claude 31/10/2026, parere Opus sulla separazione par. 6: il negativo del controllo statico,
# rieseguito sulla versione FINALE e reso un collaudo. Come utente collaudo: solo letture di file.
set -u
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/nested-work
O=${1:?cartella}; case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac; [ -e "$O" ] && exit 2; mkdir -p "$O" || exit 2
nok=0; nko=0
ok() { nok=$((nok+1)); echo "  ok      $*"; }; no() { nko=$((nko+1)); echo "  ERRATO  $*"; }
echo "controllo-azioni.sh $(sha256 -q $W/controllo-azioni.sh) controllo-azioni.py $(sha256 -q $W/controllo-azioni.py)"
sh $W/controllo-azioni.sh > $O/positivo.txt 2>&1; r=$?
[ $r = 0 ] && grep -q 'SUMMARY: 0 difetti' $O/positivo.txt && grep -q 'totale non conformi e non inerti: 0' $O/positivo.txt && ok "positivo: elenco reale conforme, 0 non conformi attivi" || no "positivo rc=$r $(tail -2 $O/positivo.txt | tr '\n' ' ')"
# negativi: uno per forma, ciascuno da solo in un elenco con gli strumenti veri
neg() {	# neg <nome> <riga dello script finto> <testo atteso nel DIFETTO>
	printf '#!/bin/sh\n%s\n' "$2" > $O/$1.sh
	{ cat $W/APPROVATI-sequenza.sha256; echo "0000 $O/$1.sh"; } > $O/$1.elenco
	sh $W/controllo-azioni.sh $O/$1.elenco > $O/$1.txt 2>&1; r=$?
	[ $r = 1 ] && grep "DIFETTO $O/$1.sh" $O/$1.txt | grep -q -- "$3" && ok "$1: preso ($3)" || no "$1: rc=$r $(grep DIFETTO $O/$1.txt | head -2 | tr '\n' ' ')"
}
neg kldload_senza_guardia 's_kldload() { sudo -n /sbin/kldload "$1"; }' "non e' una lettura"
neg sudo_in_stringa 'fai "sudo -n /sbin/kldload $A"' "non e' una lettura"
neg kill_come_lettura 'o_segnala() { sudo -n /bin/kill -"$1" "$2"; }' "non e' una lettura"
neg dtrace_con_o 'sudo -n /usr/sbin/dtrace -q -n "$S" -o /etc/passwd &' "non e' una lettura"
neg dtrace_con_c 'sudo -n /usr/sbin/dtrace -c /bin/sh -n BEGIN' "non e' una lettura"
neg ldd 'L=$(sudo -n /usr/bin/ldd "$Q")' "non e' una lettura"
neg get_memseg_con_destroy 'sudo -n /usr/sbin/bhyvectl --vm=vm2 --destroy --get-memseg 2>&1' "non e' una lettura"
# parere Opus «letture chiuse» par. 3.1-3.3: per occorrenza, non per riga
neg lettura_e_azione_stessa_riga 'x=$(sudo -n /usr/bin/true 2>/dev/null); sudo -n /sbin/kldload "$M"' "non e' una lettura"
neg due_sudo_una_guardia 'guardia_azione && sudo -n /usr/sbin/devctl freeze; sudo -n /sbin/kldunload -n vmm-restore.ko' "non e' una lettura"
neg due_sudo_un_comando 'guardia_azione && sudo -n /usr/sbin/devctl freeze && x=$(sudo -n /sbin/kldunload -n vmm-restore.ko)' "non e' una lettura"
neg guardia_con_or 'guardia_azione || sudo -n /sbin/kldload "$M"' "non e' una lettura"
neg messaggio_che_copre 'mc_stop "sudo -n non disponibile"; sudo -n /sbin/kldload "$M"' "non e' una lettura"
neg dtrace_l_con_c "sudo -n /usr/sbin/dtrace -l -n 'vmm:::fatal-latch' -n 'vmm:::fatal-ritorno' -n 'vmm:vmx:nested:veptunemul' -n 'vmm:vmx:nested:opndfatal' -n ':::fatal-latch' -n ':::fatal-ritorno' -n ':::veptunemul' -n ':::opndfatal' 2>/dev/null -c /bin/sh" "non e' una lettura"
neg true_con_coda 'sudo -n /usr/bin/true 2>/dev/null -- /sbin/kldload x' "non e' una lettura"
# v4 (parere Opus «wrapper di root» par. 4.1): percorso completo, doas, su
neg sudo_percorso_completo '/usr/local/bin/sudo -n /sbin/kldload "$M"' "non e' una lettura"
neg doas 'doas /sbin/kldload "$M"' "non e' una lettura"
neg su_in_testa "su -m root -c '/sbin/kldload x'" "non e' una lettura"
neg su_dopo_separatore "x=1; su root -c 'kldunload vmm'" "non e' una lettura"
neg guardia_senza_caricarla 'x() { guardia_azione && sudo -n /sbin/kldunload -n vmm-restore.ko; }' "non carica guardia.sh"
# la sequenza con una chiamata diretta
sed 's/^inv smoke-C1 t_smoke stadio10/inv smoke-C1 sh $C\/smoke-modulo.sh stadio10/' $W/sequenza-kut.sh > $O/seq-diretta.sh
sh $W/controllo-azioni.sh $W/APPROVATI-sequenza.sha256 $O/seq-diretta.sh > $O/seq-diretta.txt 2>&1; r=$?
[ $r = 1 ] && grep -q 'nomina strumenti fuori dalla riga T_\*' $O/seq-diretta.txt && ok "sequenza con chiamata diretta: presa" || no "sequenza diretta rc=$r"
NG=vmm-get; NG=${NG}tone	# composto: questo collaudo non deve nominarlo per intero
printf '#!/bin/sh\nsudo /usr/local/sbin/%s 1 scambio x\n' "$NG" > $O/nomina-gettone.sh
sh $W/controllo-azioni.sh $W/APPROVATI-sequenza.sha256 $W/sequenza-kut.sh $O/nomina-gettone.sh > $O/gettone.txt 2>&1; r=$?
[ $r = 1 ] && grep -q "${NG} nominato in: .*nomina-gettone.sh" $O/gettone.txt && ok "script che nomina ${NG}: preso" || no "${NG} rc=$r"
# punto 4: un INERTE si riconosce dalla forma esatta, non dal commento
mkdir -p $O/altri
printf '#!/bin/sh\n# INERTE (finto: solo il commento)\nsudo -n /sbin/kldload x\n' > $O/altri/solo-commento.sh
printf '#!/bin/sh\n# INERTE (vero)\necho "INERTE: vero" >&2; exit 4\nsudo -n /sbin/kldload x\n' > $O/altri/inerte-vero.sh
printf '#!/bin/sh\nset -u\n. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh\nsudo -n /sbin/kldload x\n' > $O/altri/suite.sh
printf '#!/bin/sh\nguardia_azione && sudo -n /sbin/kldload x\n' > $O/altri/guardato.sh
sh $W/controllo-azioni.sh "" "" "" $O/altri > $O/altri.txt 2>&1
grep -q "non conforme: .*altri/solo-commento.sh" $O/altri.txt && ok "inerte solo per commento: NON conforme" || no "solo-commento non segnalato: $(grep 'non conforme' $O/altri.txt | tr '\n' ' ')"
grep -q "altri/inerte-vero.sh" $O/altri.txt && no "inerte vero segnalato" || ok "inerte nella forma esatta: saltato"
grep -q "altri/suite.sh" $O/altri.txt && no "suite col preambolo segnalata" || ok "suite col preambolo: saltata"
grep -q "altri/guardato.sh" $O/altri.txt && no "script guardato segnalato" || ok "script con la guardia: conforme"
# falso positivo da evitare: "su" come parola in un messaggio non e' un elevatore
printf '#!/bin/sh\necho "6 dispositivi su ppt, su richiesta"\n' > $O/su-parola.sh
{ cat $W/APPROVATI-sequenza.sha256; echo "0000 $O/su-parola.sh"; } > $O/su-parola.elenco
sh $W/controllo-azioni.sh $O/su-parola.elenco > $O/su-parola.txt 2>&1 && ok "\"su\" in un messaggio: nessun falso positivo" || no "su-parola: $(grep DIFETTO $O/su-parola.txt | head -1)"
echo "SUMMARY: $nok ok, $nko errati"
[ $nko = 0 ]
