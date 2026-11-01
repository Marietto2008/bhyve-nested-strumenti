# gettone-lib.sh -- Claude 31/10-01/11/2026, pareri Opus (incidente par. 3.2; «wrapper di root» par. 2). PREPARATA OFFLINE.
# COPIA INSTALLATA DI ROOT: /usr/local/libexec/claude-vmm/gettone-lib.sh (root:wheel 0444, write_files di nuageinit); la
# sorgente e' nested-work/installazione/files/usr/local/libexec/claude-vmm/. I wrapper caricano SOLO la copia installata;
# i collaudi (utente collaudo) caricano la sorgente con VL_DIR puntata all'albero installazione/files.
# Il consenso dell'utente come CAPACITA' verificata dal sistema. Il gettone e' un file di root (/var/run/claude-gettone,
# root:wheel 0644) creato SOLO da vmm-gettone, che sudo concede con la PASSWORD dell'utente. Il wrapper root vmm-azione
# esegue un'operazione d'host solo se gettone_valido dice si'. Formato (una chiave per riga, nessun'altra riga):
#   gettone 1
#   creato <epoch>            scade <epoch>          (durata massima 12 ore)
#   elenco <sha256 di APPROVATI-sequenza.sha256>
#   passi <op>[,<op>...]      fra: scambio distruggi ombra avvio-vm
#   sequenza <descrizione libera>
GETTONE_DURATA_MAX=43200
GETTONE_OPS="scambio distruggi ombra avvio-vm"
# gettone_valido <file> <operazione> <sha dell'elenco attuale> <ora epoch> <uid proprietario atteso: 0 in produzione>
# stampa il motivo del rifiuto; ritorna 0 solo se TUTTO torna
gettone_valido() {
	gf=$1; gop=$2; gsha=$3; gora=$4; guid=$5
	[ -f "$gf" ] && [ ! -L "$gf" ] || { echo "gettone assente"; return 1; }
	set -- $(/usr/bin/stat -f '%u %Lp' "$gf")
	[ "$1" = "$guid" ] || { echo "gettone di uid $1, atteso $guid"; return 1; }
	case "$2" in 644|640|600|444|440|400) ;; *) echo "permessi del gettone $2: scrivibile da altri"; return 1;; esac
	[ "$(/usr/bin/grep -c '' "$gf")" = 6 ] || { echo "gettone di $(/usr/bin/grep -c '' "$gf") righe, attese 6"; return 1; }
	for k in gettone creato scade elenco passi sequenza; do
		[ "$(/usr/bin/grep -c "^$k " "$gf")" = 1 ] || { echo "chiave '$k' assente o ripetuta"; return 1; }
	done
	gv=$(/usr/bin/sed -n 's/^gettone //p' "$gf"); gc=$(/usr/bin/sed -n 's/^creato //p' "$gf"); gs=$(/usr/bin/sed -n 's/^scade //p' "$gf")
	ge=$(/usr/bin/sed -n 's/^elenco //p' "$gf"); gp=$(/usr/bin/sed -n 's/^passi //p' "$gf")
	[ "$gv" = 1 ] || { echo "versione del gettone '$gv'"; return 1; }
	case "$gc$gs" in *[!0-9]*|'') echo "date non numeriche"; return 1;; esac
	[ "$gc" -le "$gora" ] || { echo "gettone creato nel futuro"; return 1; }
	[ "$gora" -lt "$gs" ] || { echo "gettone SCADUTO"; return 1; }
	[ $((gs - gc)) -le $GETTONE_DURATA_MAX ] || { echo "durata oltre il massimo"; return 1; }
	echo "$ge" | /usr/bin/grep -qx '[0-9a-f]\{64\}' || { echo "sha dell'elenco malformato"; return 1; }
	[ "$ge" = "$gsha" ] || { echo "l'elenco degli strumenti e' cambiato dopo il gettone ($gsha, gettone $ge)"; return 1; }
	for o in $(echo "$gp" | /usr/bin/tr ',' ' '); do
		case " $GETTONE_OPS " in *" $o "*) ;; *) echo "operazione sconosciuta nel gettone: $o"; return 1;; esac
	done
	case ",$gp," in *",$gop,"*) ;; *) echo "operazione '$gop' non autorizzata dal gettone ($gp)"; return 1;; esac
	echo "gettone valido per '$gop' fino a $gs"
	return 0
}

# vmm_azione_decidi <elenco approvati> <primitiva> [argomenti] -- parere Opus sulla separazione par. 3.1-3.5.
# Funzione PURA rispetto ai privilegi: decide, non esegue. I fatti dell'host arrivano da tre funzioni che il wrapper
# definisce con le letture vere e il collaudo con valori dati: va_ctime <vm>, va_memseg <vm> (sha di --get-memseg),
# va_blocklist (moduli che devmatch -p propone per i ppt, calcolati come in modulo-caldo), va_kenv_originale <nome>
# (valore della variabile PRIMA della prima operazione kenv della finestra del gettone, oppure "<assente>"; il wrapper
# lo registra come root -- parere Opus «letture chiuse» par. 4.2: il ripristino esatto deve essere ammesso).
# Uscita 0: stampa "OP <operazione del gettone>" e poi l'argv da eseguire, UN argomento per riga.
# Uscita 1: stampa "RIFIUTO <motivo>".
vmm_azione_decidi() {
	vl=$1; shift
	[ -r "$vl" ] || { echo "RIFIUTO elenco approvato illeggibile"; return 1; }
	case "${1:-}" in
	kldload)
		[ $# = 2 ] || { echo "RIFIUTO kldload: uso"; return 1; }
		vh=$(/usr/bin/awk -v f="$2" '$1 !~ /^#/ && $2 == f {print $1}' "$vl")
		[ -n "$vh" ] || { echo "RIFIUTO kldload $2: non nell'elenco approvato"; return 1; }
		case "$2" in */vmm-restore.ko) ;; *) echo "RIFIUTO kldload $2: solo moduli vmm-restore.ko"; return 1;; esac
		[ "$(/sbin/sha256 -q "$2" 2>/dev/null)" = "$vh" ] || { echo "RIFIUTO kldload $2: sha diverso dall'approvato"; return 1; }
		case "$2" in
		/boot/kernel/*) printf 'OP scambio\n/sbin/kldload\n%s\n' "$2";;	# cartella di root: si carica sul posto
		*)	# parere Opus «wrapper di root» par. 2.2c: il file del workspace si COPIA in una cartella di root, si verifica la
			# COPIA e si carica la copia (nome finale vmm-restore.ko: kldload ne ricava il nome del modulo)
			printf 'OP scambio\nCOPIA %s %s\n/sbin/kldload\n%s/%s/vmm-restore.ko\n' "$2" "$vh" "${VA_ART:-/var/db/claude-vmm-azione/art}" "$vh";;
		esac;;
	kldunload)
		[ $# = 1 ] || { echo "RIFIUTO kldunload: uso"; return 1; }
		printf 'OP scambio\n/sbin/kldunload\n-n\nvmm-restore.ko\n';;
	devctl)
		[ $# = 2 ] && { [ "$2" = freeze ] || [ "$2" = thaw ]; } || { echo "RIFIUTO devctl: solo freeze o thaw"; return 1; }
		printf 'OP scambio\n/usr/sbin/devctl\n%s\n' "$2";;
	kenv-set)
		[ $# = 3 ] || { echo "RIFIUTO kenv-set: uso"; return 1; }
		case "$2" in
		boot_safe)
			vo=$(va_kenv_originale boot_safe)
			[ "$3" = YES ] || { [ "$vo" != "<assente>" ] && [ "$3" = "$vo" ]; } || { echo "RIFIUTO kenv-set boot_safe '$3': solo YES o il ripristino esatto del valore originale ('$vo')"; return 1; };;
		devmatch_blocklist)
			vb=$(va_blocklist); vo=$(va_kenv_originale devmatch_blocklist)
			# la lista che modulo-caldo imposta: l'originale (se c'era) + ogni candidato mancante, in ordine (mc_blocklist_voluta)
			vu=""; [ "$vo" != "<assente>" ] && vu=$vo
			for vm in $vb; do case " $vu " in *" $vm "*) ;; *) vu=${vu:+$vu }$vm;; esac; done
			if [ -n "$vb" ] && [ -n "$vu" ] && [ "$3" = "$vu" ]; then :
			elif [ "$vo" != "<assente>" ] && [ "$3" = "$vo" ]; then :
			else echo "RIFIUTO kenv-set devmatch_blocklist '$3': ammessi solo l'unione originale+devmatch ('$vu') o il ripristino esatto ('$vo')"; return 1; fi;;
		*) echo "RIFIUTO kenv-set: nome non ammesso '$2'"; return 1;;
		esac
		printf 'OP scambio\n/bin/kenv\n%s=%s\n' "$2" "$3";;
	kenv-unset)
		[ $# = 2 ] && { [ "$2" = boot_safe ] || [ "$2" = devmatch_blocklist ]; } || { echo "RIFIUTO kenv-unset: nome non ammesso"; return 1; }
		printf 'OP scambio\n/bin/kenv\n-u\n%s\n' "$2";;
	distruggi)
		[ $# = 4 ] || { echo "RIFIUTO distruggi: uso distruggi vm2 <ctime> <sha memseg>"; return 1; }
		[ "$2" = vm2 ] || { echo "RIFIUTO distruggi: solo vm2 (la VM della campagna: da aggiungere con la sua identita')"; return 1; }
		echo "$4" | /usr/bin/grep -qx '[0-9a-f]\{64\}' || { echo "RIFIUTO distruggi: sha della memseg malformato"; return 1; }
		vc=$(va_ctime "$2"); vm=$(va_memseg "$2")
		[ -n "$vc" ] && [ "$vc" = "$3" ] || { echo "RIFIUTO distruggi: ctime di $2 '$vc', autorizzato '$3'"; return 1; }
		[ -n "$vm" ] && [ "$vm" = "$4" ] || { echo "RIFIUTO distruggi: memseg di $2 diversa da quella autorizzata"; return 1; }
		printf 'OP distruggi\n/usr/sbin/bhyvectl\n--vm=vm2\n--destroy\n';;
	ombra)
		[ $# = 2 ] && { [ "$2" = 0 ] || [ "$2" = 1 ]; } || { echo "RIFIUTO ombra: 0 o 1"; return 1; }
		printf 'OP ombra\n/sbin/sysctl\nhw.vmm.vmx.nested_shadow_vmcs=%s\n' "$2";;
	avvio-vm|ferma-dtrace)
		echo "RIFIUTO $1: primitiva non ancora implementata (progetto nel rapporto; finche' manca, [omesso] non si toglie)"; return 1;;
	*)	echo "RIFIUTO primitiva sconosciuta: '${1:-}'"; return 1;;
	esac
	return 0
}

# vmm_azione_valuta <elenco> <gettone> <ora epoch> <uid del gettone> <primitiva> [argomenti]
# Tutta la decisione del wrapper, senza privilegi: vmm_azione_decidi, poi il gettone per l'operazione DECISA (non per
# quella dichiarata), legato allo sha dell'elenco presente. Uscita 0: "OP <op>", "GETTONE <motivo>", poi l'argv, uno per
# riga. Uscita 1: "RIFIUTO <motivo>".
vmm_azione_valuta() {
	vv_l=$1; vv_g=$2; vv_ora=$3; vv_uid=$4; shift 4
	vv_d=$(vmm_azione_decidi "$vv_l" "$@") || { echo "$vv_d"; return 1; }
	vv_op=$(echo "$vv_d" | /usr/bin/sed -n '1s/^OP //p')
	vv_m=$(gettone_valido "$vv_g" "$vv_op" "$(/sbin/sha256 -q "$vv_l" 2>/dev/null)" "$vv_ora" "$vv_uid") || { echo "RIFIUTO gettone: $vv_m"; return 1; }
	echo "OP $vv_op"; echo "GETTONE $vv_m"; echo "$vv_d" | /usr/bin/sed 1d
}

# vmm_lettura_decidi <primitiva> [argomenti] -- pareri Opus «letture chiuse» par. 4 e «wrapper di root» par. 2. Le LETTURE come
# root, a elenco chiuso, senza gettone. Root non scrive MAI nei percorsi di marietto (par. 4.1): ogni primitiva scrive
# solo su stdout/stderr, i file li crea il chiamante. Ogni programma eseguito (.d) sta in $VL_DIR con lo sha scritto
# qui sopra. ldd non c'e' piu': non ha bisogno di root (par. 2.2d). Fatti dall'host (per ferma-sonde): vl_comm <pid>, vl_uid <pid>, vl_args <pid>.
# Uscita 0: "LETTURA <nome>" e poi l'argv, uno per riga. Uscita 1: "RIFIUTO <motivo>".
# I programmi che vmm-lettura esegue SENZA gettone stanno nella cartella installata di root e i loro sha sono scritti QUI
# (parere Opus «wrapper di root» par. 2.2a): cambiarli e' una reinstallazione, non una modifica nel workspace.
VL_DIR=${VL_DIR:-/usr/local/libexec/claude-vmm}
VL_SHA_SONDE=a06434630d4548c7c7f9cfd418ac03b9ec7f4b8ad3cb75f493d30a2e07227405
VL_SHA_KLD=add66720ecd65a1e0620f93e81ec5bb9f98f32a103cff5e9fcf9f8839eb02b10
VL_SHA_FBT=30ce9e9f732bbbf1d1dd0ffb40102abe70da05a33db0851e0cc4841c9702a6f3
vl_approvato() {	# vl_approvato <file> <sha scritto qui>
	[ "$(/sbin/sha256 -q "$1" 2>/dev/null)" = "$2" ]
}
vmm_lettura_decidi() {
	vd_sonde=$VL_DIR/sonde-opnd-v2.d; vd_kld=$VL_DIR/kld-loadcnt.d; vd_fbt=$VL_DIR/ptpad-fbt-ripfix-nested.d
	case "${1:-}" in
	ping)	[ $# = 1 ] || { echo "RIFIUTO ping: uso"; return 1; }
		printf 'LETTURA ping\n/usr/bin/true\n';;
	memseg)	[ $# = 2 ] && [ "$2" = vm2 ] || { echo "RIFIUTO memseg: solo vm2"; return 1; }
		printf 'LETTURA memseg\n/usr/sbin/bhyvectl\n--vm=vm2\n--get-memseg\n';;
	fstat-vmm) [ $# = 2 ] && [ "$2" = vm2 ] || { echo "RIFIUTO fstat-vmm: solo vm2"; return 1; }
		printf 'LETTURA fstat-vmm\n/usr/bin/fstat\n/dev/vmm/vm2\n';;
	kld-loadcnt) [ $# = 1 ] || { echo "RIFIUTO kld-loadcnt: uso"; return 1; }
		vl_approvato "$vd_kld" "$VL_SHA_KLD" || { echo "RIFIUTO kld-loadcnt: $vd_kld non approvato o cambiato"; return 1; }
		printf 'LETTURA kld-loadcnt\n/usr/sbin/dtrace\n-s\n%s\nvmm-restore.ko\n' "$vd_kld";;
	sonde-lista) [ $# = 1 ] || { echo "RIFIUTO sonde-lista: uso"; return 1; }
		printf 'LETTURA sonde-lista\n/usr/sbin/dtrace\n-l\n'
		for vp in 'vmm:::fatal-latch' 'vmm:::fatal-ritorno' 'vmm:vmx:nested:veptunemul' 'vmm:vmx:nested:opndfatal' \
		    ':::fatal-latch' ':::fatal-ritorno' ':::veptunemul' ':::opndfatal'; do printf -- '-n\n%s\n' "$vp"; done;;
	fbt-compila) [ $# = 1 ] || { echo "RIFIUTO fbt-compila: uso"; return 1; }
		vl_approvato "$vd_fbt" "$VL_SHA_FBT" || { echo "RIFIUTO fbt-compila: $vd_fbt non approvato o cambiato"; return 1; }
		printf 'LETTURA fbt-compila\n/usr/sbin/dtrace\n-e\n-s\n%s\n1\n' "$vd_fbt";;
	sonde)	[ $# = 2 ] || { echo "RIFIUTO sonde: uso sonde <limite in secondi>"; return 1; }
		case "$2" in ''|*[!0-9]*) echo "RIFIUTO sonde: limite non intero"; return 1;; esac
		[ "$2" -ge 60 ] && [ "$2" -le 7200 ] || { echo "RIFIUTO sonde: limite fuori da 60..7200 s"; return 1; }
		vl_approvato "$vd_sonde" "$VL_SHA_SONDE" || { echo "RIFIUTO sonde: $vd_sonde non approvato o cambiato"; return 1; }
		printf 'LETTURA sonde\n/usr/sbin/dtrace\n-s\n%s\n%s\n' "$vd_sonde" "$2";;
	ferma-sonde)
		[ $# = 4 ] || { echo "RIFIUTO ferma-sonde: uso ferma-sonde <pid> <TERM|KILL> <limite>"; return 1; }
		case "$2" in ''|*[!0-9]*) echo "RIFIUTO ferma-sonde: pid non numerico"; return 1;; esac
		[ "$3" = TERM ] || [ "$3" = KILL ] || { echo "RIFIUTO ferma-sonde: solo TERM o KILL"; return 1; }
		case "$4" in ''|*[!0-9]*) echo "RIFIUTO ferma-sonde: limite non intero"; return 1;; esac
		[ "$(vl_comm "$2")" = dtrace ] || { echo "RIFIUTO ferma-sonde: $2 non e' un processo dtrace"; return 1; }
		[ "$(vl_uid "$2")" = 0 ] || { echo "RIFIUTO ferma-sonde: $2 non e' di root"; return 1; }
		[ "$(vl_args "$2")" = "/usr/sbin/dtrace -s $vd_sonde $4" ] || { echo "RIFIUTO ferma-sonde: $2 non e' il dtrace delle sonde approvate ('$(vl_args "$2")')"; return 1; }
		printf 'LETTURA ferma-sonde\n/bin/kill\n-%s\n%s\n' "$3" "$2";;
	*)	echo "RIFIUTO lettura sconosciuta: '${1:-}'"; return 1;;
	esac
	return 0
}
