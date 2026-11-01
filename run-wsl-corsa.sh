#!/bin/sh
# run-wsl-corsa.sh -- Claude 01/11/2026. UNA corsa della campagna Hyper-V/WSL2 sullo STADIO 10 (decisione dell'utente
# del 01/11: si torna alla campagna). Stesso schema e stessi strumenti del runner KUT (run-opnd-kut.sh):
#   produttore del manifest opnd-manifest.sh (OM_VM=vm0:12), guardia_azione su ogni azione, sonde in un .d approvato con
#   stdout rediretto da qui, arresto di dtrace con om_ferma_dtrace, ombra con le trappole del produttore, sigillo.
# Una corsa = la serie del 20 e 22/10: avvio di Windows 11 (vm0-12-wsl.sh), desktop (explorer via SSH), dentro WSL
# `uname -r` e la prova d'integrita' SHA-256 della serie B1, contatori VMfail per vCPU, spegnimento pulito da Windows.
# Dopo la corsa 2 del 01/11 (CreateVm/ERROR_TIMEOUT): sonde v2 (motivi d'uscita dell'L2 per finestra di 10 s), serie dei
# contatori ogni 10 s (stats-serie.txt, la stessa lettura approvata di o_vm_stats) e orari delle fasi (fasi.txt).
# NESSUNA distruzione di vm0:12 qui: la fa la sequenza con vmm-residuo.sh --distruggi-da <questa sessione>.
#   sh run-wsl-corsa.sh --prova|--esegui|--esegui-ombra <cartella nuova in logs/>
# Uscite: 0 PASS | 1 FAIL | 4 STOP prima della VM | 5 sessione non valida | 6 operatore | 7 DTrace non attivata |
#         8 sessione incompleta
set -u
B=/mnt/linuxulator2/vm/wsl2/fbsd
. /mnt/linuxulator2/vm/wsl2/fbsd/caldo/guardia.sh
guardia_azione || { echo "STOP: guardia: nessuna corsa"; exit 4; }
MOD=$B/logs/stadio10-congelato-20261031/vmm-restore.ko
MOD_SHA=142a08b6c0bcfefc05e994dacd8d5e80a6d8d303a18dfc7efeca838779bab006
MOD_BUILDID=2310be805fcec6b897ab56bad70c389271c108a2
OIDS="hw.vmm.vmx.nested_ept12_viol_emul_reflected hw.vmm.vmx.vept_h2_viol_final hw.vmm.gla2gpa_restart_capped hw.vmm.fatal_latches hw.vmm.vmx.nested_operand_fatal"
OID_ATTESO=11011
VMDEF=$B/campagna-wsl/vm0-12-wsl.sh
CONF=$B/campagna-wsl/macchina.conf
BHYVE=$B/stage/current/sbin/bhyve
BHYVE_SHA=d393103a6f56885100fc63c0b8bc37921878e0bb3dc3af2a0b556fbd390e2955
PASSO_PS1=$B/wsl-passo.ps1
SONDE_D=$B/installazione/files/usr/local/libexec/claude-vmm/sonde-wsl-v3.d
SONDE_D_SHA=5cfa80da7e7ee62409f40b10c622da4f32d3ab38c47aa41fab4cf2435853ff68
SONDE_ET=sonde-wsl-v3
VER=$B/wsl-verdetto.py
OM=$B/opnd-manifest.sh
PY=/usr/local/bin/python3
TMO=3600				# limite della corsa intera; le sonde si chiudono da sole a TMO + 60 s
ferma() { echo "STOP: $*"; exit 4; }
[ $# = 2 ] || [ $# = 3 ] || { echo "uso: $0 --prova|--esegui|--esegui-ombra <cartella nuova in logs/> [stadio10|stadio11]"; exit 4; }
MODO=$1; OUT=$2; STADIO=${3:-stadio10}
# parere #172 di Astra (qualifica limitata): lo stadio 11 = la sua copia congelata, firma OID 11111 (l'oid di P3 c'e')
case "$STADIO" in
stadio10) ;;
stadio11) MOD=$B/logs/stadio11-congelato-20261101/vmm-restore.ko
	MOD_SHA=3bfc6ae8b8c938f131d428cc353dafcad4e99169fbe45cd6a288f9e7e70d4a43
	MOD_BUILDID=7947f8af2c30b6a1e051ff067d265fe433490b83
	OID_ATTESO=11111;;
*) ferma "stadio '$STADIO': stadio10 o stadio11";;
esac
case "$MODO" in --prova|--esegui|--esegui-ombra) ;; *) ferma "modo $MODO";; esac
case "$OUT" in /mnt/linuxulator2/vm/wsl2/fbsd/logs/*) ;; *) ferma "uscita fuori da nested-work/logs: $OUT";; esac
[ -e "$OUT" ] && ferma "$OUT esiste gia'"
cv() { sed -n "s/^$1=//p" "$CONF" | head -1; }
VM=$(cv vm); WH=$(cv host_windows); WU=$(cv utente_windows); WPF=$(cv password_file)
[ "$VM" = vm0:12 ] || ferma "macchina.conf: vm '$VM'"

echo "=== preflight (sola lettura) ==="
[ "$(sha256 -q "$MOD")" = "$MOD_SHA" ] || ferma "copia congelata diversa da $STADIO"
CAR=$(/sbin/kldstat -v -n vmm-restore.ko 2>/dev/null | sed -n 's/.*vmm-restore\.ko (\(.*\))$/\1/p' | head -1)
sig=""; for o in $OIDS; do sig=$sig$(/sbin/sysctl -n $o >/dev/null 2>&1 && echo 1 || echo 0); done
NONCAR=""
if [ "$CAR" != "$MOD" ] || [ "$sig" != "$OID_ATTESO" ]; then
	[ "$MODO" = --prova ] || { echo "STOP: caricato '$CAR' (oid $sig), non $STADIO"; exit 6; }
	NONCAR="caricato '$CAR' (oid $sig): $STADIO NON e' caricato (lo scambio e' un passo separato)"
fi
nm "$MOD" | grep -Eq " [tT] vmx_shvmcs_enter\$" || ferma "vmx_shvmcs_enter assente dal modulo"
[ "$(sha256 -q "$BHYVE")" = "$BHYVE_SHA" ] || ferma "bhyve diverso da quello della serie"
[ "$(sha256 -q "$SONDE_D")" = "$SONDE_D_SHA" ] || ferma "programma D diverso da quello approvato"
grep -q "DTRACE_ATTIVO $SONDE_ET" "$SONDE_D" || ferma "il programma D non stampa l'etichetta $SONDE_ET"
[ -r "$VER" ] && [ -r "$OM" ] && [ -r "$VMDEF" ] && [ -r "$PASSO_PS1" ] || ferma "strumenti mancanti"
. "$OM"
OM_VM=$VM
# vivo <pid>: `kill -0` su un processo di root (sudo) dà EPERM anche se e' vivo -> si usa ps
vivo() { /bin/ps -p "$1" > /dev/null 2>&1; }
o_vm_stats() { sudo -n /usr/sbin/bhyvectl --vm="$1" --cpu="$2" --get-stats 2>&1; }
v=$(/bin/ps -ax -o pid= -o comm= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'); [ -n "$v" ] && { echo "$v"; ferma "una VM e' gia' viva"; }
[ -z "$(ls /dev/vmm 2>/dev/null)" ] || ferma "/dev/vmm non vuoto ($(ls /dev/vmm | tr '\n' ' ')): nessuna distruzione implicita"
[ "$(/sbin/sysctl -n hw.vmm.iommu.initialized 2>/dev/null)" = 0 ] || ferma "hw.vmm.iommu.initialized != 0: lo scambio a caldo del ritorno sarebbe rifiutato"
NP=$(kenv -q pptdevs | wc -w | tr -d ' ')
[ "$(pciconf -l 2>/dev/null | grep -c '^ppt')" = "$NP" ] || ferma "i ppt legati non sono quelli di pptdevs ($NP)"
kldstat -q -n amdgpu.ko && ferma "amdgpu caricato"
[ "$(/sbin/sysctl -n hw.vmm.vmx.nested_shadow_vmcs 2>/dev/null)" = 0 ] || [ -n "$NONCAR" ] || ferma "hw.vmm.vmx.nested_shadow_vmcs != 0 all'inizio"
for k in disco_immagine_ident disco_dati_ident; do
	geom disk list | awk -v id="$(cv $k)" '$1 == "ident:" && $2 == id {t=1} END {exit !t}' || ferma "disco $k ($(cv $k)) assente"
done
nc -z -w 2 "$WH" 22 2>/dev/null && ferma "$WH risponde gia' sulla porta 22: un'altra Windows accesa?"
echo "preflight OK: $STADIO $MOD_SHA, bhyve $BHYVE_SHA, sonde $SONDE_D_SHA, VM $VM, ppt $NP"
[ -n "$NONCAR" ] && echo "PROVA: $NONCAR"
[ "$MODO" = --prova ] && { echo "PROVA: nessuna VM avviata"; [ -n "$NONCAR" ] && exit 6; exit 0; }

mkdir -p "$OUT" || ferma "mkdir $OUT"
# vCPU ATTESE dalla configurazione (parere #172: l'analisi non le deduce da quelle viste): sockets*cores*threads
NV=$(cv cpu | tr ',' '\n' | awk -F= '$2 ~ /^[0-9]+$/ {p = (p ? p : 1) * $2} END {print p + 0}')
[ "$NV" -ge 1 ] 2>/dev/null || ferma "macchina.conf: cpu '$(cv cpu)' non leggibile"
echo "vcpu $NV" > "$OUT/serie-attese.txt"
[ "$MODO" = --esegui-ombra ] && { om_ombra_accendi || exit 4; }
# variabili d'identita' lette da om_apri (stesso formato delle sessioni KUT)
PIANO=wsl; MOD_BUILDID=$MOD_BUILDID; FLAT_SHA=-; DRV_SHA=$(sha256 -q "$VMDEF"); VER_SHA=$(sha256 -q "$VER")
OM_SCRIPT_SHA=$(sha256 -q "$0"); QEMU=$BHYVE; QEMU_SHA=$BHYVE_SHA; QEMU_VER=bhyve-stage-current; MACCHINA=$VM
LIBV=$(ldd "$BHYVE" | awk '/libvmmapi/{print $3}'); LIBV_SHA=$(sha256 -q "$LIBV" 2>/dev/null)
VMCMD="come root (riga guardata): sh $VMDEF"
om_apri "$OUT" || { om_non_avviata "apertura non riuscita: $OM_ERR" || true; echo "STOP: $(tail -3 "$OUT/manifest.txt" | tr '\n' ' ')"; exit 4; }
om_riga "sonde $SONDE_D $SONDE_D_SHA etichetta $SONDE_ET"
om_riga "stadio $STADIO firma oid $OID_ATTESO"
# P3 (stadio 11): i walk interrotti dal limite (esito CONTESO). Una lettura fallita resta "illeggibile", mai 0; nello
# stadio 10 l'oid non esiste ("assente"). Serve a dire se la correzione e' stata ESERCITATA, non solo se non regredisce.
p3_leggi() { /sbin/sysctl -n hw.vmm.gla2gpa_restart_capped 2>/dev/null || { [ "$OID_ATTESO" = 11111 ] && echo illeggibile || echo assente; }; }
P3_PRIMA=$(p3_leggi); P3_MAX=$(/sbin/sysctl -n hw.vmm.gla2gpa_restart_max 2>/dev/null || echo -)
om_riga "p3 prima: gla2gpa_restart_capped=$P3_PRIMA gla2gpa_restart_max=$P3_MAX"
om_riga "loader.conf $(sha256 -q /boot/loader.conf) pptdevs $(kenv -q pptdevs | tr ' ' ',') iommu $(/sbin/sysctl -n hw.vmm.iommu.initialized)"
guardia_azione || ferma "guardia"; sudo -n /usr/sbin/dtrace -s "$SONDE_D" $((TMO + 60)) > "$OUT/sonde.txt" 2> "$OUT/sonde-err.txt" &
DT=$!
i=0; while [ $i -lt 15 ] && ! grep -q DTRACE_ATTIVO "$OUT/sonde.txt" 2>/dev/null; do sleep 1; i=$((i + 1)); done
if ! grep -q DTRACE_ATTIVO "$OUT/sonde.txt" 2>/dev/null; then
	om_ferma_dtrace $DT 30 || { echo "sessione: NON CHIUSA: dtrace vivo (operatore)" >> "$OUT/manifest.txt"; exit 6; }
	om_non_avviata "DTrace non attivata in 15 s" || true
	echo "STOP: DTrace non attivata in 15 s: nessuna VM avviata"; exit 7
fi

# --- la corsa
w() { sshpass -f "$WPF" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o LogLevel=ERROR "$WU@$WH" "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
wcp() { sshpass -f "$WPF" scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$@"; }
t0=$(date +%s); esito=""
guardia_azione || ferma "guardia"; sudo -n sh "$VMDEF" > "$OUT/vm.log" 2>&1 < /dev/null &
VMP=$!
echo "avvio $t0" > "$OUT/fasi.txt"
i=0; while [ $i -lt 60 ] && [ ! -e "/dev/vmm/$VM" ] && vivo $VMP; do sleep 1; i=$((i + 1)); done
[ -e "/dev/vmm/$VM" ] || esito="VM-NON-CREATA"
# serie dei contatori ogni 10 s, finche' la VM vive e fino al segnale di basta (prima dello spegnimento)
SP=""
if [ -z "$esito" ]; then
	( while vivo $VMP && [ ! -e "$OUT/.basta-serie" ]; do
		echo "T $(date +%s)"
		for c in $(/usr/bin/jot - 0 $((NV - 1))); do o_vm_stats "$VM" "$c" | sed "s/^/vcpu$c /"; done
		echo "TF $(date +%s)"
		sleep 10
	done ) > "$OUT/stats-serie.txt" 2>&1 < /dev/null &
	SP=$!
fi
desk=-1
if [ -z "$esito" ]; then
	i=0
	while [ $i -lt 90 ]; do
		vivo $VMP || { esito="BHYVE-USCITO"; break; }
		if nc -z -w 3 "$WH" 22 2>/dev/null && w 'tasklist /fi "imagename eq explorer.exe"' | grep -qi explorer; then desk=$(( $(date +%s) - t0 )); break; fi
		sleep 10; i=$((i + 1))
	done
	[ $desk -lt 0 ] && [ -z "$esito" ] && esito="NO-DESKTOP"
fi
echo "desktop $desk" > "$OUT/esito.txt"
[ $desk -ge 0 ] && echo "desktop $((t0 + desk))" >> "$OUT/fasi.txt"
if [ $desk -ge 0 ]; then
	sleep 60
	printf '%s' "-d Debian -u root -- bash -c 'uname -r; dd if=/dev/urandom of=/root/serie.bin bs=1M count=64 2>/dev/null; a=\$(sha256sum /root/serie.bin | cut -c1-64); sync; echo 3 > /proc/sys/vm/drop_caches; b=\$(sha256sum /root/serie.bin | cut -c1-64); [ \$a = \$b ] && echo SHA-OK \$a || echo SHA-DIVERSO'" > "$OUT/wsl-args.txt"
	wcp "$OUT/wsl-args.txt" "$WU@$WH:C:/claude/wsl-args.txt"
	wcp "$PASSO_PS1" "$WU@$WH:C:/claude/wsl-passo.ps1"
	w "del C:\\claude\\wsl-log.txt 2>nul & del C:\\claude\\o.txt 2>nul & schtasks /create /tn claude-wsl /tr \"powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1\" /sc once /st 00:00 /sd 01/01/2030 /ru $WU /it /rl highest /f >nul & schtasks /run /tn claude-wsl >nul" > "$OUT/wsl-avvio.txt"
	echo "wsl_inizio $(date +%s)" >> "$OUT/fasi.txt"
	j=0; while [ $j -lt 40 ]; do w 'type C:\claude\wsl-log.txt' | grep -q codice && break; sleep 10; j=$((j + 1)); done
	# parere #171 par. 3.4: wsl_fine = il runner ha VISTO la riga "codice" (fine del polling, non l'istante nel guest);
	# wsl_esaurito = tentativi finiti senza quella riga
	if [ $j -lt 40 ]; then echo "wsl_fine $(date +%s)" >> "$OUT/fasi.txt"; else echo "wsl_esaurito $(date +%s)" >> "$OUT/fasi.txt"; fi
	wcp "$WU@$WH:C:/claude/o.txt" "$OUT/wsl-o.txt" 2>/dev/null
	wcp "$WU@$WH:C:/claude/wsl-log.txt" "$OUT/wsl-log.txt" 2>/dev/null
	echo "wsl $(grep -o 'microsoft-standard-WSL2' "$OUT/wsl-o.txt" 2>/dev/null | head -1 || true)" >> "$OUT/esito.txt"
	echo "sha $(grep -oE 'SHA-OK|SHA-DIVERSO' "$OUT/wsl-o.txt" 2>/dev/null | head -1 || true)" >> "$OUT/esito.txt"
fi
# la serie si ferma prima dello spegnimento; poi i contatori finali per vCPU, con la VM ancora viva
if [ -n "$SP" ]; then : > "$OUT/.basta-serie"; wait $SP 2>/dev/null; fi
echo "spegnimento $(date +%s)" >> "$OUT/fasi.txt"
for c in $(/usr/bin/jot - 0 $((NV - 1))); do o_vm_stats "$VM" "$c" | sed "s/^/vcpu$c /"; done > "$OUT/stats.txt" 2>&1
# spegnimento pulito da Windows; bhyve esce da solo (rc 1 = poweroff)
spento=0
if vivo $VMP; then
	nc -z -w 3 "$WH" 22 2>/dev/null && w 'shutdown /s /t 0' > /dev/null
	i=0; while [ $i -lt 300 ] && vivo $VMP; do sleep 1; i=$((i + 1)); done
	if vivo $VMP; then
		esito="${esito:+$esito+}NO-SPEGNIMENTO"
		om_ferma_dtrace $VMP 30 bhyve || { echo "sessione: NON CHIUSA: bhyve ancora vivo dopo SIGKILL (operatore)" >> "$OUT/manifest.txt"; echo "OPERATORE: bhyve vivo"; exit 6; }
	else
		spento=1
	fi
fi
wait $VMP 2>/dev/null; BRC=$?
echo "bhyve_rc $BRC spento_da_windows $spento durata $(( $(date +%s) - t0 ))" >> "$OUT/esito.txt"
echo "esito ${esito:-OK}" >> "$OUT/esito.txt"
# i produttori dei log si chiudono PRIMA delle letture finali e del sigillo
sleep 1
om_ferma_dtrace $DT 30 || { echo "sessione: NON CHIUSA: dtrace ancora attivo dopo SIGKILL (operatore)" >> "$OUT/manifest.txt"; echo "OPERATORE: dtrace vivo (uscita 6)"; exit 6; }
FIN=""
[ "$MODO" = --esegui-ombra ] && { om_ombra_spegni || FIN="nested_shadow_vmcs non ripristinato a 0"; }
P3_DOPO=$(p3_leggi)
om_riga "p3 dopo: gla2gpa_restart_capped=$P3_DOPO"
echo "gla2gpa_restart_capped $P3_PRIMA $P3_DOPO" > "$OUT/contatori-p3.txt"
om_chiudi || FIN="${FIN:+$FIN; }chiusura INCOMPLETA: $OM_ERR"
grep -E '^(contatori dopo|p3 (prima|dopo)|vm0:12 dopo|ATTENZIONE)' "$OUT/manifest.txt"
cat "$OUT/esito.txt"
$PY "$VER" "$OUT" > "$OUT/VERDETTO" 2>&1
VRC=$?
cat "$OUT/VERDETTO"
om_sigilla || FIN="${FIN:+$FIN; }sigillo non riuscito"
echo "/dev/vmm dopo: $(ls /dev/vmm 2>/dev/null | tr '\n' ' ')(nessuna distruzione da questo runner)"
[ -n "$FIN" ] && { echo "sessione INCOMPLETA ($FIN): uscita 8 (verdetto $VRC)"; exit 8; }
[ $OM_VM2_ESTRANEA = 1 ] && { echo "sessione NON valida: $VM non e' l'istanza della corsa (uscita 5)"; exit 5; }
[ $OM_DT_FORZATO = 1 ] && { echo "sessione NON valida: dtrace o bhyve fermati con SIGKILL (uscita 5)"; exit 5; }
[ $OM_RICARICATO = 1 ] && { echo "sessione NON valida: il modulo non e' l'istanza dell'apertura (uscita 5)"; exit 5; }
exit $VRC
