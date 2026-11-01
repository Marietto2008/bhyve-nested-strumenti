#!/bin/sh
# test-vmm-azione.sh -- Claude 31/10/2026, parere Opus sulla separazione par. 3.2. Le DECISIONI del wrapper vmm-azione
# (vmm_azione_valuta = vmm_azione_decidi + gettone), come utente collaudo: moduli, gettoni e fatti dell'host sono dati
# del collaudo. Uso: sudo -u collaudo sh test-vmm-azione.sh <cartella in collaudi>
set -u
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh
VL_DIR=/mnt/linuxulator2/vm/nested-work/installazione/files/usr/local/libexec/claude-vmm
. $VL_DIR/gettone-lib.sh	# la SORGENTE della libreria installata (parere Opus «wrapper di root» par. 2.2e)
O=${1:?cartella}; case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac; [ -e "$O" ] && exit 2; mkdir -p "$O" || exit 2
nok=0; nko=0
ok() { nok=$((nok+1)); echo "  ok      $*"; }; no() { nko=$((nko+1)); echo "  ERRATO  $*"; }
U=$(id -u); ORA=1793500000
# moduli e elenco del collaudo: lo stadio 10 e l'ORIGINALE (verso di ritorno), un modulo fuori elenco, uno con sha cambiato
mkdir -p $O/s10 $O/orig $O/fuori $O/cambiato
echo stadio10 > $O/s10/vmm-restore.ko; echo originale > $O/orig/vmm-restore.ko; echo fuori > $O/fuori/vmm-restore.ko; echo prima > $O/cambiato/vmm-restore.ko
echo altro > $O/altro.ko
{ echo "# elenco del collaudo"
  for f in $O/s10/vmm-restore.ko $O/orig/vmm-restore.ko $O/cambiato/vmm-restore.ko $O/altro.ko; do echo "$(sha256 -q $f) $f"; done; } > $O/elenco
echo dopo > $O/cambiato/vmm-restore.ko
SE=$(sha256 -q $O/elenco)
gettone() {	# gettone <nome> <passi>
	printf 'gettone 1\ncreato %s\nscade %s\nelenco %s\npassi %s\nsequenza collaudo\n' $((ORA-10)) $((ORA+3600)) "$SE" "$2" > $O/$1; chmod 644 $O/$1
}
gettone g-tutto scambio,distruggi,ombra
gettone g-scambio scambio
# fatti dell'host
VA_CTIME=1793473984; VA_MEMSEG=$(printf 'f%.0s' $(seq 64)); VA_BL='if_cdce amdgpu'
va_ctime()  { echo "$VA_CTIME"; }
va_memseg() { echo "$VA_MEMSEG"; }
va_blocklist() { echo "$VA_BL"; }
VA_KO_boot_safe='<assente>'; VA_KO_devmatch_blocklist='<assente>'
va_kenv_originale() { eval "echo \"\$VA_KO_$1\""; }
# si (atteso: argv esatto, argomenti separati da |) / no (atteso: testo del rifiuto)
si() {	# si <nome> <argv atteso con |> <gettone> <primitiva...>
	n=$1; a=$2; g=$3; shift 3
	v=$(vmm_azione_valuta $O/elenco $O/$g $ORA $U "$@"); r=$?
	IFS='
'
	set -f; set -- $(echo "$v" | sed 1,2d | grep -v '^COPIA '); set +f; unset IFS
	VCOPIA=$(echo "$v" | sed -n 's/^COPIA //p')
	x=""; for w in "$@"; do x="${x:+$x|}$w"; done
	[ $r = 0 ] && [ "$x" = "$a" ] && ok "$n: $x" || no "$n: rc=$r argv '$x' atteso '$a' ($(echo "$v" | head -1))"
}
rifiuto() {	# rifiuto <nome> <testo atteso> <gettone> <primitiva...>
	n=$1; a=$2; g=$3; shift 3
	v=$(vmm_azione_valuta $O/elenco $O/$g $ORA $U "$@"); r=$?
	[ $r = 1 ] && echo "$v" | grep -q -- "$a" && ok "$n: $v" || no "$n: rc=$r '$v' (atteso rifiuto '$a')"
}
echo "kldload: i due versi dello scambio e i rifiuti"
# parere Opus «wrapper di root» par. 2.2c: un modulo del workspace si carica dalla COPIA di root (verificata sulla copia)
H10=$(sha256 -q $O/s10/vmm-restore.ko); HOR=$(sha256 -q $O/orig/vmm-restore.ko)
si  kldload-andata   "/sbin/kldload|/var/db/claude-vmm-azione/art/$H10/vmm-restore.ko"  g-scambio kldload $O/s10/vmm-restore.ko
[ "$VCOPIA" = "$O/s10/vmm-restore.ko $H10" ] && ok "kldload-andata: COPIA $VCOPIA" || no "kldload-andata: COPIA '$VCOPIA'"
si  kldload-ritorno  "/sbin/kldload|/var/db/claude-vmm-azione/art/$HOR/vmm-restore.ko" g-scambio kldload $O/orig/vmm-restore.ko
[ "$VCOPIA" = "$O/orig/vmm-restore.ko $HOR" ] && ok "kldload-ritorno: COPIA $VCOPIA" || no "kldload-ritorno: COPIA '$VCOPIA'"
# il modulo di /boot/kernel (cartella di root) si carica sul posto, senza copia
{ cat $O/elenco; echo "$(sha256 -q /boot/kernel/vmm-restore.ko) /boot/kernel/vmm-restore.ko"; } > $O/elenco-boot
SE_B=$(sha256 -q $O/elenco-boot); printf 'gettone 1\ncreato %s\nscade %s\nelenco %s\npassi scambio\nsequenza collaudo\n' $((ORA-10)) $((ORA+3600)) "$SE_B" > $O/g-boot; chmod 644 $O/g-boot
v=$(vmm_azione_valuta $O/elenco-boot $O/g-boot $ORA $U kldload /boot/kernel/vmm-restore.ko); r=$?
[ $r = 0 ] && [ "$(echo "$v" | sed 1,2d | tr '\n' '|')" = "/sbin/kldload|/boot/kernel/vmm-restore.ko|" ] && ok "kldload dell'originale in /boot/kernel: sul posto, senza COPIA" || no "kldload /boot/kernel: rc=$r $(echo "$v" | tr '\n' '|')"
rifiuto kldload-fuori-elenco "non nell'elenco"  g-scambio kldload $O/fuori/vmm-restore.ko
rifiuto kldload-sha-cambiato "sha diverso"      g-scambio kldload $O/cambiato/vmm-restore.ko
rifiuto kldload-non-vmm      "solo moduli vmm-restore.ko" g-scambio kldload $O/altro.ko
rifiuto kldload-uso          "uso"              g-scambio kldload
echo "kldunload, devctl"
si  kldunload        "/sbin/kldunload|-n|vmm-restore.ko" g-scambio kldunload
rifiuto kldunload-argomento "uso"               g-scambio kldunload vmm.ko
si  freeze           "/usr/sbin/devctl|freeze"  g-scambio devctl freeze
si  thaw             "/usr/sbin/devctl|thaw"    g-scambio devctl thaw
rifiuto devctl-detach "solo freeze o thaw"      g-scambio devctl detach
echo "kenv: valori chiusi"
si  boot-safe        "/bin/kenv|boot_safe=YES"  g-scambio kenv-set boot_safe YES
rifiuto boot-safe-no "solo YES"                 g-scambio kenv-set boot_safe NO
si  blocklist        "/bin/kenv|devmatch_blocklist=if_cdce amdgpu" g-scambio kenv-set devmatch_blocklist "if_cdce amdgpu"
rifiuto blocklist-altro "ammessi solo l'unione"  g-scambio kenv-set devmatch_blocklist "amdgpu"
VA_BL=''; rifiuto blocklist-devmatch-vuoto "ammessi solo l'unione" g-scambio kenv-set devmatch_blocklist ""; VA_BL='if_cdce amdgpu'
echo "kenv: ripristino esatto degli originali e unione con una blocklist preesistente (parere Opus par. 4.2)"
VA_KO_boot_safe=NO
si  boot-safe-ripristino   "/bin/kenv|boot_safe=NO"  g-scambio kenv-set boot_safe NO
rifiuto boot-safe-altro    "solo YES o il ripristino" g-scambio kenv-set boot_safe MAYBE
VA_KO_boot_safe='<assente>'
VA_KO_devmatch_blocklist='if_cdce foo'
si  blocklist-unione       "/bin/kenv|devmatch_blocklist=if_cdce foo amdgpu" g-scambio kenv-set devmatch_blocklist "if_cdce foo amdgpu"
si  blocklist-ripristino   "/bin/kenv|devmatch_blocklist=if_cdce foo" g-scambio kenv-set devmatch_blocklist "if_cdce foo"
rifiuto blocklist-unione-altro "ammessi solo l'unione" g-scambio kenv-set devmatch_blocklist "if_cdce amdgpu"
VA_KO_devmatch_blocklist='if_cdce amdgpu'
rifiuto blocklist-gia-tutta "ammessi solo l'unione" g-scambio kenv-set devmatch_blocklist "if_cdce amdgpu amdgpu"
VA_KO_devmatch_blocklist=''
si  blocklist-ripristino-vuota "/bin/kenv|devmatch_blocklist=" g-scambio kenv-set devmatch_blocklist ""
VA_KO_devmatch_blocklist='<assente>'
rifiuto kenv-altro-nome "nome non ammesso"      g-scambio kenv-set kern.securelevel 1
si  unset            "/bin/kenv|-u|boot_safe"   g-scambio kenv-unset boot_safe
rifiuto unset-altro  "nome non ammesso"         g-scambio kenv-unset vfs.root.mountfrom
echo "distruggi: identita' riconvalidata DENTRO il confine"
si  distruggi        "/usr/sbin/bhyvectl|--vm=vm2|--destroy" g-tutto distruggi vm2 $VA_CTIME $VA_MEMSEG
rifiuto distruggi-ctime  "ctime di vm2"          g-tutto distruggi vm2 1793473000 $VA_MEMSEG
rifiuto distruggi-memseg "memseg di vm2 diversa" g-tutto distruggi vm2 $VA_CTIME $(printf 'e%.0s' $(seq 64))
VA_CTIME=''; rifiuto distruggi-nodo-assente "ctime di vm2 ''" g-tutto distruggi vm2 1793473984 $VA_MEMSEG; VA_CTIME=1793473984
rifiuto distruggi-altra-vm "solo vm2"            g-tutto distruggi vm0:12 $VA_CTIME $VA_MEMSEG
rifiuto distruggi-senza-identita "uso"           g-tutto distruggi vm2
rifiuto distruggi-sha-malformato "malformato"    g-tutto distruggi vm2 $VA_CTIME abc
echo "ombra, primitive non implementate, sconosciute"
si  ombra-1          "/sbin/sysctl|hw.vmm.vmx.nested_shadow_vmcs=1" g-tutto ombra 1
rifiuto ombra-2      "0 o 1"                    g-tutto ombra 2
rifiuto avvio-vm     "non ancora implementata"  g-tutto avvio-vm F1
rifiuto ferma-dtrace "non ancora implementata"  g-tutto ferma-dtrace 123
rifiuto sconosciuta  "sconosciuta"              g-tutto sh -c id
echo "gettone: l'operazione DECISA deve essere nel gettone"
rifiuto fuori-gettone-distruggi "non autorizzata dal gettone" g-scambio distruggi vm2 $VA_CTIME $VA_MEMSEG
rifiuto fuori-gettone-ombra     "non autorizzata dal gettone" g-scambio ombra 0
rifiuto gettone-assente         "gettone assente"             g-nessuno kldunload
gettone g-vecchio scambio; sed -i '' "s/^elenco .*/elenco $(printf 'a%.0s' $(seq 64))/" $O/g-vecchio
rifiuto elenco-cambiato "cambiato dopo il gettone" g-vecchio kldunload
v=$(vmm_azione_valuta $O/non-esiste $O/g-scambio $ORA $U kldunload); [ $? = 1 ] && echo "$v" | grep -q illeggibile && ok "elenco assente: $v" || no "elenco assente: $v"
echo "il wrapper vero, come collaudo: si ferma prima di tutto"
m=$(sh /mnt/linuxulator2/vm/nested-work/installazione/files/usr/local/sbin/vmm-azione kldunload 2>&1); r=$?
[ $r = 4 ] && echo "$m" | grep -q 'non sono root' && ok "vmm-azione come collaudo: $m" || no "vmm-azione: rc=$r $m"
echo "SUMMARY: $nok ok, $nko errati"
[ $nko = 0 ]
