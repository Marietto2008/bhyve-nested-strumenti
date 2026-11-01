#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: modulo-h1fix.sh.non-conforme
echo "INERTE: modulo-h1fix.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in modulo-h1fix.sh.non-conforme" >&2; exit 4
# modulo-h1fix.sh -- Claude 28/10/2026, parere #111 §5.2. Sostituzione TEMPORANEA del modulo vmm con quello
# della correzione di H1 (r110), e ritorno al modulo originale. /boot/kernel/vmm-restore.ko NON si tocca mai:
# il modulo nuovo si carica dal percorso di staging.
#
#   modulo-h1fix.sh --prova-carica       controlli + sequenza che si eseguirebbe: NESSUNA azione
#   modulo-h1fix.sh --prova-ripristina   idem per il ritorno all'originale:       NESSUNA azione
#   modulo-h1fix.sh --carica             SOLO col consenso esplicito dell'utente al CARICAMENTO
#   modulo-h1fix.sh --ripristina         ritorno all'originale (subito dopo la sessione KUT)
#
# ⚠ PASSTHROUGH: il driver ppt sta DENTRO vmm-restore.ko. Scaricarlo stacca i dispositivi PCI legati a ppt
# (oggi 6: GPU AMD 3/0/0-1, GPU NVIDIA 4/0/0-3 con un controller USB 3); al caricamento successivo ppt li
# deve riprendere. Lo script fotografa i legami prima e li verifica dopo; se non tornano identici si ferma
# e lo dice (si risolve col riavvio dell'host, che ricarica /boot/kernel/vmm-restore.ko da loader.conf).
#
# USCITA: 0 ok; 4 STOP ai controlli (nulla fatto); 5 azione fallita (stato da guardare, vedi messaggio).
set -u
B=/mnt/linuxulator2/vm/nested-work
ORIG=/boot/kernel/vmm-restore.ko
ORIG_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9
ORIG_BID=d30f6a7f6ea6c9259b5f39604c9399564aba5f49
NEW=$B/obj-h1-ptphold-r110/mnt/linuxulator2/vm/nested-work/freebsd-h1-ptphold/amd64.amd64/sys/modules/vmm/vmm-restore.ko
NEW_SHA=d0465140490570335c295ee1c7d1584cf95a65aafaa0397b79bd78422ab86873
NEW_BID=1ba0803c8165661c9e6b0a2c0c73c32182998341
R109_SHA=4626c65e824dce3f86fbfac3a6e35228187c4dedf18b5fefd167b1f9600f0dec	# r109: da NON caricare
LOADER_SHA=$(sha256 -q /boot/loader.conf)
NUOVO_OID=hw.vmm.vmx.nested_ept12_viol_emul_reflected	# esiste solo nel modulo nuovo
DIARIO=$B/logs/modulo-h1fix-diario.txt

[ $# -eq 1 ] || { echo "uso: $0 --prova-carica|--prova-ripristina|--carica|--ripristina"; exit 4; }
MODO=$1
case "$MODO" in --prova-carica|--prova-ripristina|--carica|--ripristina) ;; *) echo "modo $MODO"; exit 4;; esac
PROVA=0; case "$MODO" in --prova-*) PROVA=1;; esac
ferma() { echo "STOP: $*"; exit 4; }
dice() { echo "$*"; [ $PROVA = 1 ] || echo "$(date '+%F %T') $MODO $*" >> "$DIARIO"; }
fai() {		# esegue (o, in prova, mostra) un passo che CAMBIA lo stato
	if [ $PROVA = 1 ]; then echo "  [prova] eseguirei: $*"; return 0; fi
	echo "  esegue: $*"; eval "$*"
}

caricato() { /sbin/kldstat -v -n vmm-restore.ko 2>/dev/null | sed -n 's/.*vmm-restore\.ko (\(.*\))$/\1/p' | head -1; }
ppt_legami() { /usr/sbin/pciconf -l 2>/dev/null | awk -F'[@:]' '/^ppt[0-9]+@/{print $1"@"$3":"$4":"$5":"$6}' | sort; }
vm_vive() { /bin/ps -ax -o pid= -o comm= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'; }
vmm_aperti() { for v in /dev/vmm/*; do [ -e "$v" ] || continue; sudo -n /usr/bin/fstat "$v" 2>/dev/null | sed 1d; done; }

echo "=== $MODO: controlli (sola lettura) ==="
[ "$(sha256 -q $ORIG)" = "$ORIG_SHA" ] || ferma "$ORIG non e' l'originale 149fa57e"
readelf -n $ORIG 2>/dev/null | grep -q "Build ID: $ORIG_BID" || ferma "build-id dell'originale diverso"
[ -r "$NEW" ] || ferma "manca il modulo nuovo $NEW"
NS=$(sha256 -q "$NEW"); [ "$NS" = "$R109_SHA" ] && ferma "il file di staging e' l'r109, da non caricare"
[ "$NS" = "$NEW_SHA" ] || ferma "modulo nuovo diverso da d0465140 ($NS)"
readelf -n "$NEW" 2>/dev/null | grep -q "Build ID: $NEW_BID" || ferma "build-id del modulo nuovo diverso"
grep -q '^vmm_name="vmm-restore"' /boot/loader.conf || ferma "loader.conf non carica vmm-restore al boot"
v=$(vm_vive); [ -n "$v" ] && { echo "$v"; ferma "una VM e' viva"; }
v=$(vmm_aperti); [ -n "$v" ] && { echo "$v"; ferma "un nodo /dev/vmm e' aperto"; }
C=$(caricato); [ -n "$C" ] || ferma "vmm-restore.ko non risulta caricato"
CS=$(sha256 -q "$C")
NODI=$(ls /dev/vmm 2>/dev/null | tr '\n' ' ')
PPT0=$(ppt_legami)
echo "caricato: $C ($CS)"
echo "nodi /dev/vmm: ${NODI:-nessuno}"
echo "legami ppt: $(echo $PPT0)"
echo "loader.conf sha256 $LOADER_SHA"
/sbin/kldstat -v -n vmm-restore.ko | sed -n 1,2p

case "$MODO" in
*carica)
	[ "$C" = "$ORIG" ] && [ "$CS" = "$ORIG_SHA" ] || ferma "per caricare il nuovo deve essere caricato l'originale (ora: $C)"
	/sbin/sysctl -n $NUOVO_OID >/dev/null 2>&1 && ferma "$NUOVO_OID esiste gia' col modulo originale?"
	DA=$ORIG; A=$NEW; A_SHA=$NEW_SHA; ATTESO_OID=si;;
*ripristina)
	if [ "$C" = "$ORIG" ] && [ "$CS" = "$ORIG_SHA" ]; then
		[ $PROVA = 1 ] || ferma "e' gia' caricato l'originale: niente da ripristinare"
		echo "(prova) ora e' caricato l'originale: mostro la sequenza come se fosse caricato il nuovo"
	else
		[ "$C" = "$NEW" ] && [ "$CS" = "$NEW_SHA" ] || ferma "caricato un modulo inatteso: $C ($CS)"
	fi
	DA=$C; A=$ORIG; A_SHA=$ORIG_SHA; ATTESO_OID=no;;
esac
echo "=== $MODO: sequenza ==="
dice "da $DA a $A; ppt prima: $(echo $PPT0); nodi: ${NODI:-nessuno}"
for n in $NODI; do fai "sudo -n /usr/sbin/bhyvectl --vm=$n --destroy"; done
fai "sudo -n /sbin/kldunload vmm-restore" || { dice "kldunload FALLITO: resta caricato $(caricato)"; exit 5; }
if ! fai "sudo -n /sbin/kldload $A"; then
	dice "kldload di $A FALLITO"
	if [ "$A" != "$ORIG" ]; then
		dice "ritorno immediato all'originale"
		fai "sudo -n /sbin/kldload $ORIG" || { dice "ANCHE l'originale non si carica: vmm assente, serve il riavvio"; exit 5; }
	fi
	exit 5
fi
[ $PROVA = 1 ] && { echo "  [prova] poi verificherei: caricato = $A ($A_SHA), $NUOVO_OID $( [ $ATTESO_OID = si ] && echo presente || echo assente ), legami ppt identici a prima"; echo "PROVA: nessuna azione eseguita"; exit 0; }
sleep 1
C2=$(caricato); [ "$C2" = "$A" ] && [ "$(sha256 -q "$C2")" = "$A_SHA" ] || { dice "dopo il caricamento risulta $C2"; exit 5; }
if [ $ATTESO_OID = si ]; then /sbin/sysctl -n $NUOVO_OID >/dev/null 2>&1 || { dice "$NUOVO_OID assente col modulo nuovo"; exit 5; }
else /sbin/sysctl -n $NUOVO_OID >/dev/null 2>&1 && { dice "$NUOVO_OID ancora presente dopo il ripristino"; exit 5; }; fi
PPT1=$(ppt_legami)
if [ "$PPT1" != "$PPT0" ]; then
	dice "LEGAMI ppt CAMBIATI: prima $(echo $PPT0) / dopo $(echo $PPT1) -- passthrough da sistemare (riavvio)"
	exit 5
fi
[ "$(sha256 -q /boot/loader.conf)" = "$LOADER_SHA" ] || { dice "loader.conf cambiato?"; exit 5; }
dice "OK: caricato $A ($A_SHA); legami ppt identici; loader.conf invariato"
exit 0
