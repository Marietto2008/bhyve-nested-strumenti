#!/bin/sh
# test-vmm-lettura.sh -- Claude 01/11/2026, pareri Opus «letture chiuse» par. 4 e «wrapper di root» par. 2. Le decisioni di
# vmm-lettura (vmm_lettura_decidi della libreria SORGENTE di quella installata), come utente collaudo. I programmi D
# stanno in VL_DIR con gli sha scritti nella libreria: le varianti (programma cambiato o mancante) sono cartelle VL_DIR
# di prova. Controllo statico (par. 2.2e): ogni programma eseguito sta sotto VL_DIR; i wrapper installati caricano solo
# la libreria installata. Uso: sudo -u collaudo sh test-vmm-lettura.sh <cartella in collaudi>
set -u
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/nested-work
SRC=$W/installazione/files/usr/local/libexec/claude-vmm
VL_DIR=$SRC
. $VL_DIR/gettone-lib.sh	# la SORGENTE della libreria installata
O=${1:?cartella}; case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac; [ -e "$O" ] && exit 2; mkdir -p "$O" || exit 2
nok=0; nko=0
ok() { nok=$((nok+1)); echo "  ok      $*"; }; no() { nko=$((nko+1)); echo "  ERRATO  $*"; }
# cartelle VL_DIR di prova: un programma cambiato (sonde con un pragma distruttivo), uno mancante
mkdir -p $O/cambiato $O/senza-kld $O/senza-fbt
cp $SRC/*.d $O/cambiato/ && cp $SRC/*.d $O/senza-kld/ && cp $SRC/*.d $O/senza-fbt/
printf '#pragma D option destructive\nBEGIN { system("id"); }\n' >> $O/cambiato/sonde-opnd-v2.d
: > $O/senza-kld/kld-loadcnt.d.tolto; cat /dev/null > $O/senza-kld/kld-loadcnt.d; : > $O/senza-fbt/ptpad-fbt-ripfix-nested.d
SD=$SRC/sonde-opnd-v2.d; KLD=$SRC/kld-loadcnt.d; FBT=$SRC/ptpad-fbt-ripfix-nested.d
VC=dtrace; VU=0; VA="/usr/sbin/dtrace -s $SD 360"
vl_comm() { echo "$VC"; }; vl_uid() { echo "$VU"; }; vl_args() { echo "$VA"; }
si() {	# si <nome> <argv atteso con |> <VL_DIR> <primitiva...>
	n=$1; a=$2; VL_DIR=$3; shift 3
	v=$(vmm_lettura_decidi "$@"); r=$?
	x=$(echo "$v" | sed 1d | tr '\n' '|' | sed 's/|$//')
	# par. 2.2e: ogni programma .d nell'argv sta sotto VL_DIR
	for w in $(echo "$v" | sed 1d | grep '\.d$'); do case "$w" in "$VL_DIR"/*) ;; *) no "$n: programma fuori da VL_DIR: $w";; esac; done
	[ $r = 0 ] && [ "$x" = "$a" ] && ok "$n: $x" || no "$n: rc=$r '$x' atteso '$a' ($(echo "$v" | head -1))"
	VL_DIR=$SRC
}
rifiuto() {	# rifiuto <nome> <testo atteso> <VL_DIR> <primitiva...>
	n=$1; a=$2; VL_DIR=$3; shift 3
	v=$(vmm_lettura_decidi "$@"); r=$?
	[ $r = 1 ] && echo "$v" | grep -q -- "$a" && ok "$n: $v" || no "$n: rc=$r '$v' (atteso '$a')"
	VL_DIR=$SRC
}
si ping "/usr/bin/true" $SRC ping
rifiuto ping-argomento "uso" $SRC ping -c
si memseg "/usr/sbin/bhyvectl|--vm=vm2|--get-memseg" $SRC memseg vm2
rifiuto memseg-altra-vm "solo vm2" $SRC memseg vm0:12
rifiuto memseg-con-destroy "solo vm2" $SRC memseg "vm2 --destroy"
si fstat "/usr/bin/fstat|/dev/vmm/vm2" $SRC fstat-vmm vm2
rifiuto fstat-altro "solo vm2" $SRC fstat-vmm /etc/master.passwd
si kld-loadcnt "/usr/sbin/dtrace|-s|$KLD|vmm-restore.ko" $SRC kld-loadcnt
rifiuto kld-loadcnt-cambiato "non approvato o cambiato" $O/senza-kld kld-loadcnt
si sonde-lista "/usr/sbin/dtrace|-l|-n|vmm:::fatal-latch|-n|vmm:::fatal-ritorno|-n|vmm:vmx:nested:veptunemul|-n|vmm:vmx:nested:opndfatal|-n|:::fatal-latch|-n|:::fatal-ritorno|-n|:::veptunemul|-n|:::opndfatal" $SRC sonde-lista
rifiuto sonde-lista-argomento "uso" $SRC sonde-lista -c
si fbt-compila "/usr/sbin/dtrace|-e|-s|$FBT|1" $SRC fbt-compila
rifiuto fbt-cambiato "non approvato o cambiato" $O/senza-fbt fbt-compila
si sonde "/usr/sbin/dtrace|-s|$SD|360" $SRC sonde 360
rifiuto sonde-breve "60..7200" $SRC sonde 30
rifiuto sonde-lunga "60..7200" $SRC sonde 99999
rifiuto sonde-non-intero "non intero" $SRC sonde "360 -c /bin/sh"
rifiuto sonde-pragma-distruttivo "non approvato o cambiato" $O/cambiato sonde 360
rifiuto sonde-senza-limite "uso" $SRC sonde
si ferma-term "/bin/kill|-TERM|4242" $SRC ferma-sonde 4242 TERM 360
si ferma-kill "/bin/kill|-KILL|4242" $SRC ferma-sonde 4242 KILL 360
rifiuto ferma-hup "solo TERM o KILL" $SRC ferma-sonde 4242 HUP 360
rifiuto ferma-pid "non numerico" $SRC ferma-sonde 1-2 TERM 360
VC=sh; rifiuto ferma-non-dtrace "non e' un processo dtrace" $SRC ferma-sonde 4242 TERM 360; VC=dtrace
VU=1001; rifiuto ferma-non-root "non e' di root" $SRC ferma-sonde 4242 TERM 360; VU=0
VA="/usr/sbin/dtrace -c /bin/sh -s $SD 360"; rifiuto ferma-argv-diverso "non e' il dtrace delle sonde" $SRC ferma-sonde 4242 TERM 360
VA="/usr/sbin/dtrace -s $SD 360"; rifiuto ferma-limite-diverso "non e' il dtrace delle sonde" $SRC ferma-sonde 4242 TERM 600
rifiuto ldd-tolta "sconosciuta" $SRC ldd-qemu
rifiuto sconosciuta "sconosciuta" $SRC dtrace -c /bin/sh
echo "controllo statico dei wrapper installati (par. 2.2e)"
for f in $W/installazione/files/usr/local/sbin/vmm-azione $W/installazione/files/usr/local/sbin/vmm-lettura $W/installazione/files/usr/local/sbin/vmm-gettone; do
	x=$(grep -nE '^[[:space:]]*(\.|source)[[:space:]]' $f | grep -v '^[0-9]*:[[:space:]]*\. /usr/local/libexec/claude-vmm/gettone-lib\.sh$')
	[ -z "$x" ] && ok "${f##*/}: carica solo /usr/local/libexec/claude-vmm/gettone-lib.sh" || no "${f##*/}: carica altro: $x"
	grep -q '/mnt/linuxulator2' $f && no "${f##*/}: nomina il workspace (va letto da claude-vmm.conf)" || ok "${f##*/}: nessun percorso del workspace scritto dentro"
done
x=$(grep -nE '^[[:space:]]*(\.|source)[[:space:]]' $SRC/gettone-lib.sh)
[ -z "$x" ] && ok "gettone-lib.sh: non carica altri file" || no "gettone-lib.sh carica: $x"
for f in vmm-azione vmm-lettura; do
	n=$(grep -n 'id -u)" = 0 ] ||' $W/installazione/files/usr/local/sbin/$f | head -1 | cut -d: -f1); m=$(grep -n '^\. /usr/local/libexec' $W/installazione/files/usr/local/sbin/$f | cut -d: -f1)
	[ -n "$n" ] && [ -n "$m" ] && [ "$n" -lt "$m" ] && ok "$f: controllo di root (riga $n) prima della libreria (riga $m)" || no "$f: ordine root/libreria $n/$m"
done
m=$(sh $W/installazione/files/usr/local/sbin/vmm-lettura ping 2>&1); r=$?
[ $r = 4 ] && echo "$m" | grep -q 'non sono root' && ok "vmm-lettura come collaudo: $m" || no "vmm-lettura: rc=$r $m"
echo "SUMMARY: $nok ok, $nko errati"
[ $nko = 0 ]
