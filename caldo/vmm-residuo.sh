#!/bin/sh
# vmm-residuo.sh -- Claude 30/10/2026, parere #142 (gestione AUTORIZZATA dei residui /dev/vmm). Un nodo /dev/vmm/vm2
# lasciato da QEMU (-accel bhyve lo distrugge solo al poweroff) si distrugge SOLO se e' esattamente quello che
# l'utente ha autorizzato: stesso nome, stesso ctime, stessa mappa di memoria (hash di bhyvectl --get-memseg).
#
#   vmm-residuo.sh --verifica                       sola lettura: identita' di ogni nodo (da mostrare all'utente)
#   vmm-residuo.sh --distruggi vm2 <ctime> <memseg> distrugge vm2 SOLO se ctime e hash memseg coincidono
#   vmm-residuo.sh --distruggi-da <sessione>       (31/10, riesame Opus) istanza ricavata da manifest + stato, nessun
#                                                  argomento trascritto: solo col ramo NODO_DELLA_SESSIONE, poi come --distruggi
#   vmm-residuo.sh --classifica-ritorno <cartella della sessione>|nessuna
#        #143 §5, sola lettura: quale ramo del ritorno vale DOPO una sessione (anche fallita o fermata al preflight):
#        (#144 §2, ordine fail-closed: EMERGENZA, poi OPERATORE, poi i rami che ammettono un'azione)
#        RAMO=GIA_RIPRISTINATO    /dev/vmm vuoto, modulo ORIGINALE (es. rc=5 di modulo-caldo): nessuno scambio
#        RAMO=NESSUN_NODO         /dev/vmm vuoto, modulo RIPFIX o STADIO 9: nessuna distruzione, ritorno protetto
#        RAMO=NODO_DELLA_SESSIONE vm2 chiusa, creata da QUELLA sessione (ctime >= avvio e = manifest, stessa
#                                 memseg): stampa il --distruggi da far AUTORIZZARE all'utente per quell'istanza
#        RAMO=OPERATORE           vm2 aperta, processi VM o dtrace vivi, altri nodi, identita' dubbia: STOP, nessun
#                                 kldunload forzato
#        RAMO=EMERGENZA           nessun modulo vmm o hot-swap rimasto a meta': protocollo d'emergenza di
#                                 modulo-caldo (stato.txt), nessun comando improvvisato
#
# Rifiuta (uscita 4, nulla fatto): con --distruggi un nome diverso da vm2 (MAI vm0:12 a mano: la VM della campagna WSL
# si distrugge solo con --distruggi-da, dal manifest della sessione che l'ha creata), nodo aperto, processi bhyve/qemu vivi,
# altri nodi oltre vm2 non sono un motivo di rifiuto ma non si toccano, ctime o memseg diversi, modulo vmm assente.
# Uscita 0 = distrutto e /dev/vmm/vm2 assente; 6 = distruzione tentata ma il nodo resta (operatore).
# Accesso al sistema solo dalle funzioni r_* (sovrascritte dal collaudo, test-vmm-residuo.sh).
set -u
. /mnt/linuxulator2/vm/nested-work/caldo/guardia.sh	# 31/10/2026 (parere Opus sull'incidente): guardia comune delle azioni
r_nodi()    { /bin/ls /dev/vmm 2>/dev/null; }
r_ctime()   { /usr/bin/stat -f '%c' "/dev/vmm/$1" 2>/dev/null; }
# #169 R5: le letture d'identita' valgono solo se bhyvectl e' riuscito (pipefail): mai l'hash o il testo di un errore
r_memseg()  { ( set -o pipefail; sudo -n /usr/sbin/bhyvectl --vm="$1" --get-memseg 2>&1 | /sbin/sha256 -q ); }
r_aperto()  { [ -n "$(sudo -n /usr/bin/fstat "/dev/vmm/$1" 2>/dev/null | /usr/bin/sed 1d)" ]; }
r_vm_vive() { /bin/ps -ax -o pid= -o comm= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'; }
r_modulo()  { /sbin/kldstat -q -n vmm-restore.ko || /sbin/kldstat -q -n vmm.ko; }
r_distruggi() { guardia_azione && sudo -n /usr/sbin/bhyvectl --vm="$1" --destroy; }
r_ora()     { /bin/date '+%F %T'; }
r_memseg_testo() { ( set -o pipefail; sudo -n /usr/sbin/bhyvectl --vm="$1" --get-memseg 2>&1 | /usr/bin/tr -s ' \n' ' ' ); }	# come nel manifest
r_dtrace_vivo()  { /bin/pgrep -x dtrace; }
# identita' del modulo caricato secondo mc-logica.sh: originale | ripfix-nested | stadio9 | stadio10 | stadio11 | h2ad2 | r110 | h2 |
# incompleto:<stato> | sconosciuto:<path> (path, sha e firma OID devono coincidere TUTTI)
r_modulo_id() {
	( . /mnt/linuxulator2/vm/nested-work/caldo/mc-sistema.sh; . /mnt/linuxulator2/vm/nested-work/caldo/mc-logica.sh
	  c=$(mc_caricato); case "$c" in "completo "*) p=${c#completo };; *) echo "incompleto:$c"; exit 0;; esac
	  for i in originale ripfix-nested stadio9 stadio10 stadio11 h2ad2 r110 h2; do
		set -- $(mc_identita $i)
		[ "$p" = "$1" ] && [ "$(s_sha "$p")" = "$2" ] && mc_oid_ok "$p" && { echo $i; exit 0; }
	  done
	  echo "sconosciuto:$p" )
}
r_fase_caldo()   { /usr/bin/sed -n 's/^fase=//p' /mnt/linuxulator2/vm/nested-work/logs/modulo-caldo/stato.txt 2>/dev/null; }
# #168 par. 4: con VR_FINTO nessuna distruzione REALE e' raggiungibile (r_distruggi rifiuta finche' il finto non la
# ridefinisce) e ogni uscita e' marcata SIMULATA
if [ -n "${VR_FINTO:-}" ]; then
	r_distruggi() { echo "SIMULATO: nessuna distruzione reale"; return 1; }
	. "$VR_FINTO"
	echo "SIMULAZIONE (VR_FINTO): esito non valido come evidenza"
fi
VR_DIARIO=${VR_DIARIO:-/mnt/linuxulator2/vm/nested-work/logs/vmm-residuo/diario.txt}

vr_dice() { echo "$*"; [ "${VR_SCRIVI:-0}" = 1 ] && echo "$(r_ora) $*" >> "$VR_DIARIO"; return 0; }
vr_stop() { vr_dice "RIFIUTO: $*; nulla fatto"; exit 4; }

vr_identita() {	# stampa una riga per nodo: nome ctime memseg aperto
	for n in $(r_nodi); do
		a=no; r_aperto "$n" && a=si
		echo "$n ctime=$(r_ctime "$n") memseg=$(r_memseg "$n") aperto=$a"
	done
}

vr_distruggi() {	# vr_distruggi <nome> <ctime> <memseg>: rivalida TUTTO al momento dell'azione; esce 4/6, ritorna 0
	n=$1; c=$2; m=$3
	mkdir -p "$(dirname "$VR_DIARIO")" && VR_SCRIVI=1
	case "$n" in vm2|vm0:12) ;; *) vr_stop "solo vm2 (residuo di QEMU) o vm0:12 (VM della campagna WSL) si distruggono con questo strumento, non '$n'";; esac
	r_modulo || vr_stop "nessun modulo vmm caricato"
	v=$(r_vm_vive); [ -n "$v" ] && vr_stop "VM viva: $(echo "$v" | tr '\n' ' ')"
	r_nodi | grep -qx "$n" || vr_stop "/dev/vmm/$n non esiste"
	r_aperto "$n" && vr_stop "/dev/vmm/$n e' aperto"
	c0=$(r_ctime "$n") && [ -n "$c0" ] || vr_stop "ctime di $n non leggibile"
	m0=$(r_memseg "$n") && echo "$m0" | grep -qx '[0-9a-f]\{64\}' || vr_stop "memseg di $n non leggibile"
	[ "$c0" = "$c" ] || vr_stop "ctime di $n $c0, autorizzato $c: NON e' il nodo autorizzato"
	[ "$m0" = "$m" ] || vr_stop "memseg di $n $m0, autorizzato $m: NON e' il nodo autorizzato"
	vr_dice "$n ctime=$c0 memseg=$m0 chiuso, nessuna VM viva: distruggo (autorizzato)"
	r_distruggi "$n" "$c0" "$m0"; rc=$?	# identita' anche alla primitiva (il futuro vmm-azione la riconvalida)
	if r_nodi | grep -qx "$n"; then vr_dice "ESITO 6: bhyvectl --destroy rc=$rc ma /dev/vmm/$n resta. Operatore."; exit 6; fi
	vr_dice "ESITO 0: $n distrutto (rc=$rc); /dev/vmm: $(r_nodi | tr '\n' ' ')"
	return 0
}

vr_classifica() {	# vr_classifica <sessione>|nessuna: stampa il RAMO; solo per NODO_DELLA_SESSIONE imposta VR_RAMO, VR_C, VR_M
	VR_RAMO=; VR_C=; VR_M=
	# la VM della sessione: vm2 (KUT, QEMU) o vm0:12 (campagna WSL), dal manifest; senza sessione, vm2
	VR_NOME=vm2
	[ "$1" != nessuna ] && VR_NOME=$(sed -nE 's/^(vm2|vm0:12) (prima|dopo): .*/\1/p' "$1/manifest.txt" 2>/dev/null | head -1)
	[ -n "$VR_NOME" ] || VR_NOME=vm2
	# 1. EMERGENZA: hot-swap rimasto a meta', nessun modulo, modulo incompleto
	f=$(r_fase_caldo)
	case "${f:-fine}" in fine|nulla) ;; *) echo "RAMO=EMERGENZA hot-swap rimasto nella fase '$f' (logs/modulo-caldo/stato.txt): protocollo di modulo-caldo, nessun comando improvvisato"; return 0;; esac
	r_modulo || { echo "RAMO=EMERGENZA nessun modulo vmm caricato: protocollo di modulo-caldo, nessun comando improvvisato"; return 0; }
	mid=$(r_modulo_id)
	case "$mid" in incompleto:*) echo "RAMO=EMERGENZA modulo caricato non completo ($mid): protocollo di modulo-caldo"; return 0;; esac
	# 2. OPERATORE, qualunque sia /dev/vmm: processi VM, dtrace, altri nodi, $VR_NOME aperta, modulo non previsto
	v=$(r_vm_vive); [ -n "$v" ] && { echo "RAMO=OPERATORE processi VM vivi: $(echo "$v" | tr '\n' ' ')"; return 0; }
	v=$(r_dtrace_vivo); [ -n "$v" ] && { echo "RAMO=OPERATORE dtrace vivo ($(echo "$v" | tr '\n' ' ')): il kldunload sarebbe rifiutato"; return 0; }
	altri=$(r_nodi | grep -vx -e "$VR_NOME" -e '' | tr '\n' ' ')
	[ -n "$altri" ] && { echo "RAMO=OPERATORE nodi /dev/vmm diversi da $VR_NOME: $altri"; return 0; }
	r_nodi | grep -qx "$VR_NOME" && r_aperto "$VR_NOME" && { echo "RAMO=OPERATORE /dev/vmm/$VR_NOME e' aperto"; return 0; }
	case "$mid" in originale|ripfix-nested|stadio9|stadio10|stadio11) ;; *) echo "RAMO=OPERATORE modulo caricato non previsto dalla campagna: $mid"; return 0;; esac
	# 3. /dev/vmm vuoto: il ramo dipende dal modulo EFFETTIVAMENTE caricato
	if ! r_nodi | grep -qx "$VR_NOME"; then
		[ "$mid" = originale ] && { echo "RAMO=GIA_RIPRISTINATO /dev/vmm vuoto e modulo originale gia' caricato: nessuno scambio; solo smoke-modulo.sh originale"; return 0; }
		echo "RAMO=NESSUN_NODO /dev/vmm vuoto, modulo $mid, nessun processo VM o dtrace: ritorno protetto senza distruzione (modulo-caldo.sh --esegui $mid originale)"; return 0
	fi
	# 4. $VR_NOME chiusa: solo se e' quella del manifest della sessione indicata
	[ "$1" = nessuna ] && { echo "RAMO=OPERATORE $VR_NOME presente ma nessuna sessione di riferimento: identita' non attribuibile"; return 0; }
	# #168 par. 4: una sessione del produttore aperta e mai chiusa (interrotta) non attribuisce nulla
	if grep -qx 'sessione: APERTA' "$1/manifest.txt" 2>/dev/null && ! grep -qx 'sessione: CHIUSA' "$1/manifest.txt"; then
		echo "RAMO=OPERATORE la sessione $1 non e' conclusa (APERTA senza CHIUSA): $VR_NOME non attribuibile"; return 0
	fi
	riga=$(grep -m1 "^$VR_NOME dopo: creata " "$1/manifest.txt" 2>/dev/null)
	[ -n "$riga" ] || { echo "RAMO=OPERATORE $VR_NOME presente ma il manifest di $1 non registra la $VR_NOME della sessione"; return 0; }
	mc=$(echo "$riga" | sed -n 's/^[^ ]* dopo: creata \([0-9]*\) (avvio sessione [0-9]*) .*$/\1/p')
	ma=$(echo "$riga" | sed -n 's/^[^ ]* dopo: creata [0-9]* (avvio sessione \([0-9]*\)) .*$/\1/p')
	mm=$(echo "$riga" | sed -n 's/^[^ ]* dopo: creata [0-9]* (avvio sessione [0-9]*) \(.*\)$/\1/p')
	c0=$(r_ctime "$VR_NOME")
	# 5. ogni altro caso: OPERATORE
	mt=$(r_memseg_testo "$VR_NOME") || { echo "RAMO=OPERATORE memseg di $VR_NOME non leggibile"; return 0; }
	ms=$(r_memseg "$VR_NOME") && echo "$ms" | grep -qx '[0-9a-f]\{64\}' || { echo "RAMO=OPERATORE hash della memseg di $VR_NOME non leggibile"; return 0; }
	if [ -z "$mc" ] || [ -z "$ma" ] || [ "$c0" != "$mc" ] || [ "$mc" -lt "$ma" ] || [ "$mt" != "$mm" ]; then
		echo "RAMO=OPERATORE $VR_NOME (ctime $c0) non e' quella registrata dalla sessione (ctime $mc, avvio $ma) o memseg diversa"; return 0
	fi
	VR_RAMO=NODO_DELLA_SESSIONE; VR_C=$c0; VR_M=$ms
	echo "RAMO=NODO_DELLA_SESSIONE $VR_NOME creata dalla sessione $1 (ctime $c0 >= avvio $ma), chiusa, nessuna VM o dtrace viva"
	echo "  da AUTORIZZARE per questa istanza: sh $0 --distruggi $VR_NOME $c0 $ms"
	echo "  modulo caricato: $mid; dopo la distruzione RICLASSIFICARE prima di qualunque ritorno"
	return 0
}

case "${1:-}" in
--verifica)
	[ $# = 1 ] || { echo "uso: $0 --verifica"; exit 4; }
	r_modulo || vr_stop "nessun modulo vmm caricato"
	v=$(r_vm_vive); [ -n "$v" ] && echo "processi VM vivi: $v"
	i=$(vr_identita)
	[ -n "$i" ] && echo "$i" || echo "/dev/vmm vuoto"
	exit 0;;
--distruggi)
	guardia_azione VR_FINTO || { echo "RIFIUTO: guardia (parere Opus par. 3.3): nulla fatto"; exit 4; }
	[ $# = 4 ] || { echo "uso: $0 --distruggi vm2 <ctime> <memseg>"; exit 4; }
	# 01/11/2026: con argomenti scritti a mano SOLO vm2. vm0:12 e' la VM Windows dell'utente: si distrugge solo con
	# --distruggi-da <sessione>, cioe' quando un manifest di campagna la registra come creata da quella sessione.
	[ "$2" = vm2 ] || { mkdir -p "$(dirname "$VR_DIARIO")" && VR_SCRIVI=1; vr_stop "con --distruggi solo vm2 (residuo di QEMU), non '$2'; vm0:12 solo con --distruggi-da <sessione>"; }
	vr_distruggi "$2" "$3" "$4"
	exit 0;;
--distruggi-da)
	# Opus, riesame della sequenza sullo stadio 10, par. 3 azione 2: l'istanza si ricava dal manifest della sessione e
	# dallo stato, NON da argomenti trascritti dall'operatore. Stessa classificazione di --classifica-ritorno, poi la
	# stessa distruzione rivalidata di --distruggi; qualunque ramo diverso da NODO_DELLA_SESSIONE = rifiuto 4.
	guardia_azione VR_FINTO || { echo "RIFIUTO: guardia (parere Opus par. 3.3): nulla fatto"; exit 4; }
	[ $# = 2 ] || { echo "uso: $0 --distruggi-da <cartella della sessione>"; exit 4; }
	vr_classifica "$2"
	[ "$VR_RAMO" = NODO_DELLA_SESSIONE ] && [ -n "$VR_C" ] && [ -n "$VR_M" ] || { mkdir -p "$(dirname "$VR_DIARIO")" && VR_SCRIVI=1; vr_stop "--distruggi-da $2: il ramo non e' NODO_DELLA_SESSIONE"; }
	vr_distruggi "$VR_NOME" "$VR_C" "$VR_M"
	exit 0;;
--classifica-ritorno)
	[ $# = 2 ] || { echo "uso: $0 --classifica-ritorno <cartella della sessione>|nessuna"; exit 4; }
	vr_classifica "$2"
	exit 0;;
*) echo "uso: $0 --verifica | --distruggi vm2 <ctime> <memseg> | --distruggi-da <sessione> | --classifica-ritorno <sessione>|nessuna"; exit 4;;
esac
