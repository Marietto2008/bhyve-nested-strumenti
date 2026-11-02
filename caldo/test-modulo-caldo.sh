#!/bin/sh
# test-modulo-caldo.sh -- Claude 29/10/2026 (rev. #117). Collaudo di mc-logica.sh sul sistema SIMULATO (mc-finto.sh).
# Non tocca l'host: nessun sudo, nessun kld, nessun devctl. Ogni caso gira in un /bin/sh a se' ($$ giusto per i segnali).
# uso: sh test-modulo-caldo.sh <cartella-uscita su ZFS> [cartella-script, default: quella di questo file]
set -u
. /mnt/linuxulator2/vm/wsl2/fbsd/collaudo-preambolo.sh	# 31/10/2026 (parere Opus sull'incidente): solo utente collaudo, sudo irraggiungibile
D=${2:-$(cd "$(dirname "$0")" && pwd)}
O=${1:?cartella}
case "$O" in /mnt/linuxulator2/vm/wsl2/fbsd/*) ;; *) echo "uscita fuori dal workspace ZFS: $O"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste gia'"; exit 2; }
mkdir -p "$O" || exit 2
ORIG=/boot/kernel/vmm-restore.ko
NEW=/mnt/linuxulator2/vm/wsl2/fbsd/obj-h1-ptphold-r110/mnt/linuxulator2/vm/wsl2/fbsd/freebsd-h1-ptphold/amd64.amd64/sys/modules/vmm/vmm-restore.ko
H2AD=/mnt/linuxulator2/vm/wsl2/fbsd/obj-h2ad-a/mnt/linuxulator2/vm/wsl2/fbsd/freebsd-h2ad/sys/modules/vmm/vmm-restore.ko
RIPFIX=/mnt/linuxulator2/vm/wsl2/fbsd/logs/ripfix-congelato-20261030-r5/nested/vmm-restore.ko
S9=/mnt/linuxulator2/vm/wsl2/fbsd/logs/stadio9-congelato-20261031/vmm-restore.ko
S10=/mnt/linuxulator2/vm/wsl2/fbsd/logs/stadio10-congelato-20261031/vmm-restore.ko
S11=/mnt/linuxulator2/vm/wsl2/fbsd/logs/stadio11-congelato-20261101/vmm-restore.ko
S11L=/mnt/linuxulator2/vm/wsl2/fbsd/logs/stadio11-lapic-congelato-20261102/vmm-restore.ko
S11I=/mnt/linuxulator2/vm/wsl2/fbsd/logs/stadio11-ipi-congelato-20261102/vmm-restore.ko
H2=/mnt/linuxulator2/vm/wsl2/fbsd/obj-h2-only/mnt/linuxulator2/vm/wsl2/fbsd/freebsd-h2-efault/sys/modules/vmm/vmm-restore.ko
PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); echo "  ok   $*"; }
ko() { FAIL=$((FAIL + 1)); echo "  FAIL $*"; }
kenv_foto() { for k in boot_safe devmatch_blocklist; do printf '%s e=%s v=%s\n' $k "$(cat "$FS/kenv_$k.e")" "$(cat "$FS/kenv_$k")"; done; }

# caso <nome> <orig|new|h2> <modo> <da> <a> <iniezioni...>
#   iniezione: nome (file presente) | nome=valore (file con valore) | kenv:VAR=VAL (variabile kenv esistente)
caso() {
	N=$1; INI=$2; MODO=$3; DA=$4; A=$5; shift 5
	FS=$O/$N; export FS
	( . "$D/mc-finto.sh"; case "$INI" in new) f_init "$NEW";; h2) f_init "$H2";; h2ad2) f_init "$H2AD";; ripfix) f_init "$RIPFIX";; s9) f_init "$S9";; s10) f_init "$S10";; s11) f_init "$S11";; s11l) f_init "$S11L";; s11i) f_init "$S11I";; *) f_init "$ORIG";; esac
	  for i in "$@"; do case "$i" in
	    hw:*) f_hw_${i#hw:}; f_pci_tutti ppt;;
	    kenv:*) i=${i#kenv:}; printf '%s\n' "${i#*=}" >| "$FS/kenv_${i%%=*}"; printf '1\n' >| "$FS/kenv_${i%%=*}.e";;
	    *=*) f_set "${i%%=*}" "${i#*=}";;
	    *) : >| "$FS/$i";;
	  esac; done )
	cp "$FS/pci" "$FS/pci.prima"; kenv_foto >| "$FS/kenv.prima"
	AUT=""; [ -e "$FS/aut" ] && AUT=$(cat "$FS/aut")
	MC_VM2_AUTORIZZATA=$AUT D="$D" FS="$FS" /bin/sh -c '. "$D/mc-finto.sh"; . "$D/mc-logica.sh"; MC_DIARIO=$FS/diario; MC_STATO=$FS/stato; mc_main "$@"' mc "$MODO" "$DA" "$A" > "$FS/out" 2>&1
	RC=$?
	kenv_foto >| "$FS/kenv.dopo"
	echo "== $N (rc=$RC)"
}
rc_e()     { [ "$RC" = "$1" ] && ok "$N rc=$1" || ko "$N rc=$RC, atteso $1"; }
kld_e()    { k=$(cat "$FS/kld"); [ "$k" = "$1" ] && ok "$N kld='$1'" || ko "$N kld='$k', atteso '$1'"; }
frozen_e() { f=$(cat "$FS/frozen"); [ "$f" = "$1" ] && ok "$N frozen=$1" || ko "$N frozen=$f, atteso $1"; }
pci_ppt()  { n=$(awk '$2 == "ppt"' "$FS/pci" | wc -l | tr -d ' '); [ "$n" = 6 ] && ok "$N 6 ppt" || ko "$N ppt=$n su 6"; }
pci_libere() { n=$(awk '$2 == "none"' "$FS/pci" | wc -l | tr -d ' '); [ "$n" = 6 ] && ok "$N 6 funzioni libere e intoccate" || ko "$N libere=$n su 6"; }
pci_invariata() { cmp -s "$FS/pci" "$FS/pci.prima" && ok "$N pci invariata" || ko "$N pci cambiata"; }
amdgpu_no() { [ "$(cat "$FS/carico_amdgpu")" = 0 ] && ok "$N amdgpu NON caricato" || ko "$N amdgpu caricato"; }
nvidia_no() { [ "$(cat "$FS/carico_nvidia")" = 0 ] && ok "$N nvidia NON caricato" || ko "$N nvidia caricato"; }
ppt_n() { n=$(awk '$2 == "ppt"' "$FS/pci" | wc -l | tr -d ' '); [ "$n" = "$1" ] && ok "$N $1 ppt" || ko "$N ppt=$n, attesi $1"; }
kenv_come_prima() { cmp -s "$FS/kenv.prima" "$FS/kenv.dopo" && ok "$N kenv identico a prima (valore ed esistenza)" || ko "$N kenv: prima [$(tr '\n' ' ' < "$FS/kenv.prima")] dopo [$(tr '\n' ' ' < "$FS/kenv.dopo")]"; }
kenv_protetto() { grep -q 'boot_safe e=1 v=YES' "$FS/kenv.dopo" && grep -q 'devmatch_blocklist e=1 v=.*amdgpu' "$FS/kenv.dopo" && ok "$N protezione kenv LASCIATA" || ko "$N protezione kenv assente: $(tr '\n' ' ' < "$FS/kenv.dopo")"; }
ev_ha()    { grep -q -- "$1" "$FS/eventi" && ok "$N evento '$1'" || ko "$N manca evento '$1'"; }
ev_non()   { grep -q -- "$1" "$FS/eventi" && ko "$N evento inatteso '$1'" || ok "$N nessun evento '$1'"; }
mai_senza_freeze() { ev_non VIOLAZIONE; }
nessuna_asta() { ev_non 'ASTA SENZA PPT'; }
out_ha()   { grep -q -- "$1" "$FS/out" && ok "$N uscita contiene '$1'" || ko "$N uscita senza '$1'"; }
nessuna_azione() { grep -qE 'freeze|kldunload|kldload|thaw|destroy' "$FS/eventi" && ko "$N azioni: $(tr '\n' ';' < "$FS/eventi")" || ok "$N nessuna azione su freeze/moduli/VM"; grep -qs ESEGUO "$FS/diario" && ko "$N il diario dice ESEGUO" || ok "$N nessuna esecuzione nel diario"; }
nessun_evento() { [ -s "$FS/eventi" ] && ko "$N eventi: $(tr '\n' ';' < "$FS/eventi")" || ok "$N nessun evento sul sistema"; }
nessun_diario() { [ -e "$FS/diario" ] && ko "$N diario scritto in prova" || ok "$N nessun diario"; }
stop_nel_diario() { grep -qs STOP "$FS/diario" && ok "$N STOP annotato nel diario" || ko "$N STOP non annotato"; }
statico() {	# controlli sul sorgente della logica
	n=$(grep -c 's_thaw' "$D/mc-logica.sh"); [ "$n" = 1 ] && ok "statico: s_thaw chiamato in UN solo punto (mc_thaw_nostro)" || ko "statico: s_thaw in $n punti"
	awk '/^mc_thaw_nostro\(\)/,/^}/' "$D/mc-logica.sh" | grep -q '\[ \$MC_FROZEN = 1 \] || return 0' && ok "statico: thaw solo con freeze nostro" || ko "statico: thaw senza controllo di proprieta'"
	grep -q 'kenv [a-z_]*+=' "$D/mc-logica.sh" "$D/mc-sistema.sh" && ko "statico: '+=' con kenv" || ok "statico: nessun '+=' con kenv"
}

echo "### percorsi normali"
caso T01-orig-orig orig --esegui originale originale
rc_e 0; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T02-orig-r110 orig --esegui originale r110
rc_e 0; kld_e "completo $NEW"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T03-r110-orig new --esegui r110 originale
rc_e 0; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze
caso T05-vm2-residuo orig --esegui originale r110 vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
rc_e 0; ev_ha 'destroy vm2'; pci_ppt; kenv_come_prima

echo "### kenv (#117 P0)"
caso K1-blocklist-assente orig --esegui originale originale
ev_ha 'kenv boot_safe=YES'; ev_ha 'kenv devmatch_blocklist=amdgpu'; ev_ha 'kenv -u devmatch_blocklist'; ev_ha 'kenv -u boot_safe'; kenv_come_prima
caso K2-blocklist-vuota orig --esegui originale originale kenv:devmatch_blocklist=
rc_e 0; ev_ha 'kenv devmatch_blocklist=amdgpu'; ev_non 'kenv -u devmatch_blocklist'; kenv_come_prima
caso K3-blocklist-altri orig --esegui originale originale "kenv:devmatch_blocklist=if_cdce foo"
rc_e 0; ev_ha 'kenv devmatch_blocklist=if_cdce foo amdgpu'; kenv_come_prima
caso K4-blocklist-ha-amdgpu orig --esegui originale originale "kenv:devmatch_blocklist=foo amdgpu"
rc_e 0; ev_non 'kenv devmatch_blocklist='; ev_non 'amdgpu amdgpu'; kenv_come_prima
caso K5-boot_safe-preesistente orig --esegui originale originale kenv:boot_safe=NO
rc_e 0; ev_ha 'kenv boot_safe=YES'; ev_ha 'kenv boot_safe=NO'; kenv_come_prima
caso K6-kenv-non-impostabile orig --esegui originale originale kenv_set_fail
rc_e 4; ev_non freeze; ev_non kld; kenv_come_prima; out_ha 'protezione kenv non impostabile'
caso K7-kenv-rilettura-diversa orig --esegui originale originale kenv_rilettura_diversa
rc_e 4; ev_non freeze; ev_non kld; kenv_come_prima
caso K8-kenv-ripristino-fallito orig --esegui originale originale kenv_unset_fail
rc_e 6; kld_e "completo $ORIG"; pci_ppt; out_ha 'kenv NON ripristinato'; out_ha 'OPERATORE'

echo "### errori di caricamento"
caso T06-r110-non-carica orig --esegui originale r110 fail_load_new
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; nessuna_asta
caso T07-niente-si-carica orig --esegui originale r110 fail_load_new fail_load_orig
rc_e 6; kld_e nessuno; frozen_e 1; pci_libere; amdgpu_no; kenv_protetto; nessuna_asta; out_ha 'enumerazione/probe differiti globalmente'; out_ha 'recupero tramite operatore'
caso T08-unload-rifiutato orig --esegui originale r110 fail_unload
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_invariata; kenv_come_prima
caso T09-unload-parziale orig --esegui originale r110 partial_unload
rc_e 6; frozen_e 1; pci_libere; amdgpu_no; kenv_protetto; nessuna_asta
caso T10-ritorno-non-carica new --esegui r110 originale fail_load_orig
rc_e 6; kld_e nessuno; frozen_e 1; pci_libere; amdgpu_no; kenv_protetto

echo "### catture e interferenze (#117 P1)"
caso T11-cattura-xhci-orig orig --esegui originale originale cattura_al_thaw
rc_e 6; frozen_e 0; out_ha 'VERIFICA FALLITA'; out_ha 'OPERATORE'; out_ha 'pci0:4:0:2 -> pci0:4:0:2 xhci'
caso T12-cattura-xhci-r110 orig --esegui originale r110 cattura_al_thaw
rc_e 6; kld_e "completo $ORIG"; out_ha "torno all'originale"
caso T13-freeze-occupato orig --esegui originale r110 freeze_ebusy
rc_e 4; kld_e "completo $ORIG"; pci_invariata; kenv_come_prima
caso T14a-devmatch-estraneo orig --esegui originale r110 devmatch_estraneo
rc_e 0; ev_ha 'boot_safe=YES, esce subito'; ev_non 'devmatch estraneo: THAW'; nessuna_asta; amdgpu_no; pci_ppt; kenv_come_prima
caso T14b-thaw-a-mano orig --esegui originale r110 thaw_manuale
rc_e 6; out_ha 'ANOMALIA: thaw rifiutato'; ev_ha 'thaw EBUSY'; amdgpu_no
caso T15-segnale-dopo-unload orig --esegui originale r110 segnale_dopo_unload=1
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; out_ha 'TRAP'

echo "### devmatch gia' in volo (#118 T25)"
caso T25a-inflight-si-quieta orig --esegui originale r110 inflight_s=3
rc_e 0; out_ha "barriera: attendo un devmatch gia' avviato"; out_ha 'barriera: nessun devmatch in esecuzione (attesa 3s)'
out_ha 'seconda rilettura kenv prima del freeze'; ev_non 'devmatch IN VOLO'; nessuna_asta; pci_ppt; amdgpu_no; kenv_come_prima
caso T25b-inflight-non-si-quieta orig --esegui originale r110 inflight_s=99
rc_e 4; ev_non freeze; ev_non kld; kenv_come_prima; out_ha 'barriera: devmatch ANCORA in esecuzione'; out_ha 'barriera devmatch non superata'

echo "### macchine diverse: niente BDF/ID/driver scritti nello script"
caso G1-solo-radeon orig --esegui originale originale hw:solo_amd
rc_e 0; ppt_n 2; out_ha '2 dispositivi ppt'; ev_ha 'kenv devmatch_blocklist=amdgpu'; amdgpu_no; kenv_come_prima; nessuna_asta
caso G2-solo-nvidia orig --esegui originale r110 hw:solo_nvidia
rc_e 0; ppt_n 4; out_ha '4 dispositivi ppt'; ev_ha 'kenv devmatch_blocklist=nvidia'; ev_non 'amdgpu'; nvidia_no; kenv_come_prima
caso G3-due-candidati orig --esegui originale originale hw:due_candidati
rc_e 0; ppt_n 6; ev_ha 'kenv devmatch_blocklist=amdgpu nvidia'; out_ha "seconda rilettura kenv prima del freeze: boot_safe=YES, devmatch_blocklist='amdgpu nvidia'"; kenv_come_prima
caso G4-due-candidati-senza-freeze-protetti orig --esegui originale originale hw:due_candidati devmatch_estraneo
rc_e 0; ev_ha 'boot_safe=YES, esce subito'; amdgpu_no; nvidia_no; ppt_n 6
caso G5-pptdevs-diviso orig --esegui originale originale "kenv:pptdevs=3/0/0 3/0/1" "kenv:pptdevs2=4/0/0 4/0/1 4/0/2 4/0/3"
rc_e 0; ppt_n 6; out_ha '6 dispositivi ppt'; kenv_come_prima
caso G6-pptdevs-con-assente orig --esegui originale originale "kenv:pptdevs=3/0/0 3/0/1 4/0/0 4/0/1 4/0/2 4/0/3 9/0/0"
rc_e 0; out_ha '9:0:0 -> non presente sul bus'; out_ha '6 dispositivi ppt'
caso G7-pptdevs-voce-non-su-ppt orig --esegui originale originale "pci=pci0:3:0:0 vgapci 1 0x1002 0x73ff" "kenv:pptdevs=3/0/0"
rc_e 4; nessun_evento; out_ha "e' in pptdevs ma e' legato a 'vgapci'"
caso G8-nvidia-gia-caricato orig --esegui originale originale hw:due_candidati carico_nvidia=1
rc_e 4; nessun_evento; out_ha 'moduli candidati gia'"'"' caricati: nvidia'
caso G9-blocklist-ha-gia-tutto orig --esegui originale originale hw:due_candidati "kenv:devmatch_blocklist=nvidia amdgpu"
rc_e 0; ev_non 'kenv devmatch_blocklist='; kenv_come_prima

echo "### preflight: STOP senza toccare nulla"
caso T16-iommu-usato orig --esegui originale r110 iommu=1;            rc_e 4; nessun_evento; stop_nel_diario
caso T17-vm-viva orig --esegui originale r110 "vm_procs=4242 bhyve";  rc_e 4; nessun_evento; stop_nel_diario
caso T18-nodo-estraneo orig --esegui originale r110 vmm_nodes=vm0:12; rc_e 4; nessun_evento; stop_nel_diario
caso T19-vm2-aperto orig --esegui originale r110 vmm_nodes=vm2 vm2_aperto; rc_e 4; nessun_evento; stop_nel_diario
caso T20-amdgpu-gia orig --esegui originale r110 carico_amdgpu=1;   rc_e 4; nessun_evento; stop_nel_diario
caso T21-staging-r109 orig --esegui originale r110 new_e_r109;        rc_e 4; nessun_evento; stop_nel_diario
caso T22-da-sbagliato orig --esegui r110 originale;                   rc_e 4; nessun_evento; stop_nel_diario
caso T23-pci-incompleta orig --esegui originale r110 "pci=pci0:3:0:0 vgapci 1 0x1002 0x73ff"; rc_e 4; nessun_evento; stop_nel_diario
caso T24-prova orig --prova originale r110;                           rc_e 0; nessun_evento; nessun_diario; out_ha 'PROVA, nessuna azione'

echo "### H2 (parere #119): terza identita'"
caso T30-orig-h2 orig --esegui originale h2
rc_e 0; kld_e "completo $H2"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T31-h2-orig h2 --esegui h2 originale
rc_e 0; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze
caso T32-h2-non-carica orig --esegui originale h2 fail_load_h2
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; nessuna_asta
caso T33-cattura-h2 orig --esegui originale h2 cattura_al_thaw
rc_e 6; kld_e "completo $ORIG"; out_ha "h2 caricato ma la verifica e' fallita: torno all'originale"
caso T34-h2-ritorno-non-carica h2 --esegui h2 originale fail_load_orig
rc_e 6; kld_e nessuno; frozen_e 1; pci_libere; amdgpu_no; kenv_protetto
# 02/11/2026: l'originale (boot) e' lo stadio 11, firma 11111: il modulo sbagliato e' quello a cui MANCA un oid
caso T35-orig-senza-oid-h2 orig --esegui originale h2 orig_senza_h2;  rc_e 4; nessun_evento; stop_nel_diario
# oid di r110 che RESTA dopo il ritorno all'originale (modulo sbagliato rimasto): la verifica deve fallire
caso T36-orig-senza-r110-dopo h2 --esegui h2 originale orig_senza_r110; rc_e 6; out_ha 'VERIFICA FALLITA'; out_ha 'oid(r110=0,h2=1,p3=1,fatal=1,opnd=1)'
# #120 B1/C5: la variante RITIRATA con P3 non passa per h2, ne' da caricare ne' da caricata
caso T42-staging-h2-e-p3 orig --esegui originale h2 h2_e_p3;         rc_e 4; nessun_evento; stop_nel_diario
caso T43-caricato-con-p3 h2 --esegui h2 originale oid_p3_finto;      rc_e 4; nessun_evento; stop_nel_diario
caso T44-p3-dopo-il-carico orig --esegui originale h2 oid_p3_dopo
rc_e 5; kld_e "completo $ORIG"; out_ha "h2 caricato ma la verifica e' fallita"; pci_ppt; amdgpu_no; kenv_come_prima
caso T37-r110-dichiarato-ma-h2 h2 --esegui r110 originale;          rc_e 4; nessun_evento; stop_nel_diario
caso T38-orig-senza-oid-r110 orig --esegui originale h2 orig_senza_r110; rc_e 4; nessun_evento; stop_nel_diario
caso T39-h2-h2 h2 --esegui h2 h2;                                    rc_e 4; nessun_evento
caso T40-prova-h2 orig --prova originale h2;                          rc_e 0; nessun_evento; nessun_diario; out_ha 'secondo scambio automatico h2 -> originale'
caso T41-r110-h2 new --esegui r110 h2
rc_e 0; kld_e "completo $H2"; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze

echo "### H2-AD (parere #123): identita' h2ad2"
caso T50-orig-h2ad2 orig --esegui originale h2ad2
rc_e 0; kld_e "completo $H2AD"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T51-h2ad2-orig h2ad2 --esegui h2ad2 originale
rc_e 0; kld_e "completo $ORIG"; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze
caso T52-h2ad2-non-carica orig --esegui originale h2ad2 fail_load_h2ad
rc_e 5; kld_e "completo $ORIG"; pci_ppt; amdgpu_no; kenv_come_prima
caso T53-h2ad2-dichiarato-ma-h2 h2 --esegui h2ad2 originale;          rc_e 4; nessun_evento; stop_nel_diario
caso T54-h2ad2-con-p3 orig --esegui originale h2ad2 oid_p3_dopo
rc_e 5; kld_e "completo $ORIG"; out_ha "h2ad2 caricato ma la verifica e' fallita"; pci_ppt; amdgpu_no
caso T55-prova-h2ad2 orig --prova originale h2ad2;                   rc_e 0; nessun_evento; nessun_diario; out_ha 'secondo scambio automatico h2ad2 -> originale'

echo "### RIPFIX nested (parere #142): identita' ripfix-nested, quarto oid hw.vmm.fatal_latches"
caso T60-orig-ripfix orig --esegui originale ripfix-nested
rc_e 0; kld_e "completo $RIPFIX"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T61-ripfix-orig ripfix --esegui ripfix-nested originale
rc_e 0; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T62-ripfix-non-carica orig --esegui originale ripfix-nested fail_load_ripfix
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; nessuna_asta
# dichiarato ripfix-nested ma caricato h2ad2 (stessi oid r110/h2, nessun fatal): STOP al preflight
caso T63-ripfix-dichiarato-ma-h2ad2 h2ad2 --esegui ripfix-nested originale; rc_e 4; nessun_evento; stop_nel_diario
# dichiarato h2ad2 ma il modulo caricato ha hw.vmm.fatal_latches (e' un RIPFIX): STOP
caso T64-h2ad2-con-oid-fatal h2ad2 --esegui h2ad2 originale oid_fatal_finto; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'fatal=1'
# il file congelato e' quello, ma il modulo caricato non espone fatal_latches: la verifica fallisce, si torna all'originale
caso T65-ripfix-senza-oid-fatal orig --esegui originale ripfix-nested ripfix_senza_fatal
rc_e 5; kld_e "completo $ORIG"; out_ha "ripfix-nested caricato ma la verifica e' fallita"; out_ha 'oid(r110=1,h2=1,p3=0,fatal=0,opnd=0)'; pci_ppt; amdgpu_no; kenv_come_prima
# la copia congelata e' cambiata (hash diverso): STOP prima di qualunque azione
caso T66-ripfix-cambiato orig --esegui originale ripfix-nested ripfix_ricompilato; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'non integra'
caso T67-h2ad2-ripfix h2ad2 --esegui h2ad2 ripfix-nested
rc_e 0; kld_e "completo $RIPFIX"; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze
caso T68-prova-ripfix orig --prova originale ripfix-nested;          rc_e 0; nessun_evento; nessun_diario; out_ha 'secondo scambio automatico ripfix-nested -> originale'
# oid fatal che RESTA dopo il ritorno all'originale: la verifica deve fallire (modulo sbagliato rimasto)
caso T69-orig-senza-fatal-dopo ripfix --esegui ripfix-nested originale orig_senza_fatal; rc_e 6; out_ha 'VERIFICA FALLITA'; out_ha 'oid(r110=1,h2=1,p3=1,fatal=0,opnd=1)'
caso T70-ripfix-ripfix ripfix --esegui ripfix-nested ripfix-nested;  rc_e 4; nessun_evento
# il ritorno all'originale dal RIPFIX con vm2 residua (QEMU): distrutta SOTTO freeze, come per gli altri
caso T71-ripfix-orig-vm2 ripfix --esegui ripfix-nested originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
rc_e 0; ev_ha 'destroy vm2'; kld_e "completo $ORIG"; pci_ppt; kenv_come_prima

echo "### STADIO 9 (parere #167R1 par. 9.5): identita' stadio9, quinto oid hw.vmm.vmx.nested_operand_fatal"
caso T80-orig-s9 orig --esegui originale stadio9
rc_e 0; kld_e "completo $S9"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T81-s9-orig s9 --esegui stadio9 originale
rc_e 0; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T82-s9-non-carica orig --esegui originale stadio9 fail_load_s9
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; nessuna_asta
# dichiarato stadio9 ma caricato il RIPFIX: STOP al preflight, gia' sul percorso del modulo caricato
caso T83-s9-dichiarato-ma-ripfix ripfix --esegui stadio9 originale;  rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S9'"
# percorso e file dello stadio 9, ma i sysctl del caricato sono quelli del RIPFIX (niente opnd): la firma lo ferma
caso T83b-s9-caricato-senza-opnd s9 --esegui stadio9 originale s9_senza_opnd; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'fatal=1 opnd=0'
# dichiarato ripfix-nested ma il modulo caricato ha nested_operand_fatal (e' uno stadio 9): STOP
caso T84-ripfix-con-oid-opnd ripfix --esegui ripfix-nested originale oid_opnd_finto; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'opnd=1'
# il file congelato e' quello, ma il modulo caricato non espone nested_operand_fatal: verifica fallita, ritorno all'originale
caso T85-s9-senza-oid-opnd orig --esegui originale stadio9 s9_senza_opnd
rc_e 5; kld_e "completo $ORIG"; out_ha "stadio9 caricato ma la verifica e' fallita"; out_ha 'oid(r110=1,h2=1,p3=0,fatal=1,opnd=0)'; pci_ppt; amdgpu_no; kenv_come_prima
# la copia congelata e' cambiata (hash diverso): STOP prima di qualunque azione
caso T86-s9-cambiato orig --esegui originale stadio9 s9_ricompilato; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'non integra'
# dichiarato stadio9 e caricato stadio9, ma il file su disco non e' piu' quello: STOP (il caricato non e' verificabile)
caso T87-s9-caricato-cambiato s9 --esegui stadio9 originale s9_ricompilato; rc_e 4; nessun_evento; stop_nel_diario
caso T88-ripfix-s9 ripfix --esegui ripfix-nested stadio9
rc_e 0; kld_e "completo $S9"; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze
caso T89-s9-ripfix s9 --esegui stadio9 ripfix-nested
rc_e 0; kld_e "completo $RIPFIX"; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze
caso T90-prova-s9 orig --prova originale stadio9;                 rc_e 0; nessun_evento; nessun_diario; out_ha 'secondo scambio automatico stadio9 -> originale'; out_ha "kldload $S9"
# oid opnd che RESTA dopo il ritorno all'originale: la verifica deve fallire
caso T91-orig-senza-opnd-dopo s9 --esegui stadio9 originale orig_senza_opnd; rc_e 6; out_ha 'VERIFICA FALLITA'; out_ha 'oid(r110=1,h2=1,p3=1,fatal=1,opnd=0)'
caso T92-s9-s9 s9 --esegui stadio9 stadio9;                       rc_e 4; nessun_evento
# il ritorno all'originale dallo stadio 9 con vm2 residua (QEMU): distrutta SOTTO freeze
caso T93-s9-orig-vm2 s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
rc_e 0; ev_ha 'destroy vm2'; kld_e "completo $ORIG"; pci_ppt; kenv_come_prima; mai_senza_freeze
# P3 rifiutato anche per lo stadio 9 (#120 B1 vale per ogni identita')
caso T94-s9-con-p3 s9 --esegui stadio9 originale oid_p3_finto;     rc_e 4; nessun_evento; stop_nel_diario
caso T95-identita-ignota orig --esegui originale stadio8;          rc_e 4; nessun_evento; out_ha 'stadio9'

echo "### #168 par. 5: vm2 distrutta SOLO se identificata e autorizzata, riconvalidata sotto freeze"
caso T96-vm2-senza-autorizzazione s9 --esegui stadio9 originale vmm_nodes=vm2;   rc_e 4; nessun_evento; stop_nel_diario; out_ha 'senza autorizzazione'
caso T97-vm2-ctime-diverso s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793360000 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; rc_e 4; nessun_evento; out_ha "NON e' quella autorizzata"
caso T98-vm2-memseg-diversa s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; rc_e 4; nessun_evento
caso T99-vm2-cambiata-sotto-freeze s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' vm2_cambia_sotto_freeze
rc_e 4; ev_non 'destroy'; ev_non kldunload; ev_ha thaw; frozen_e 0; kld_e "completo $S9"; kenv_come_prima; pci_invariata; out_ha 'nessuna distruzione'
caso T100-prova-vm2 s9 --prova stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; rc_e 0; nessun_evento; out_ha 'bhyvectl --vm=vm2 --destroy'

echo "### #169 R5: letture dell'identita' fallite e distruzione non riuscita"
caso T101-memseg-illeggibile s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' vm2_memseg_rotto
rc_e 4; nessun_evento; out_ha "identita' di vm2 non leggibile"
caso T102-ctime-illeggibile s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' vm2_ctime_rotto
rc_e 4; nessun_evento; out_ha "identita' di vm2 non leggibile"
caso T103-memseg-illeggibile-sotto-freeze s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' vm2_memseg_rotto_sotto_freeze
rc_e 4; ev_non destroy; ev_non kldunload; ev_ha thaw; kld_e "completo $S9"; kenv_come_prima; out_ha "non leggibile dopo il preflight"
caso T104-destroy-fallita s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' destroy_fallisce
rc_e 6; ev_ha 'destroy vm2'; ev_non kldunload; ev_ha thaw; frozen_e 0; kld_e "completo $S9"; pci_invariata; out_ha 'distruzione di vm2 NON riuscita (rc 1'
caso T105-destroy-rc0-nodo-resta s9 --esegui stadio9 originale vmm_nodes=vm2 'aut=1793362388 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' destroy_rc0_resta
rc_e 6; ev_non kldunload; ev_ha thaw; kld_e "completo $S9"; out_ha 'distruzione di vm2 NON riuscita (rc 0, nodi: vm2'

echo "### STADIO 10: stessa firma OID dello stadio 9, distinti per percorso, sha e build-id"
caso T110-orig-s10 orig --esegui originale stadio10
rc_e 0; kld_e "completo $S10"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T111-s10-orig s10 --esegui stadio10 originale
rc_e 0; kld_e "completo $ORIG"; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T112-s10-dichiarato-ma-s9 s9 --esegui stadio10 originale;      rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S10'"
caso T113-s9-dichiarato-ma-s10 s10 --esegui stadio9 originale;      rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S9'"
caso T114-s10-cambiato orig --esegui originale stadio10 s10_ricompilato; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'non integra'
caso T115-s10-non-carica orig --esegui originale stadio10 fail_load_s10
rc_e 5; kld_e "completo $ORIG"; pci_ppt; kenv_come_prima
caso T116-s9-s10 s9 --esegui stadio9 stadio10
rc_e 0; kld_e "completo $S10"; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T117-prova-s10 orig --prova originale stadio10;               rc_e 0; nessun_evento; nessun_diario; out_ha "kldload $S10"

echo "### STADIO 11 (#172): firma OID 11111, l'unica con l'oid di P3"
caso T120-orig-s11 orig --esegui originale stadio11
rc_e 0; kld_e "completo $S11"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T121-s11-orig s11 --esegui stadio11 originale
rc_e 0; kld_e "completo $ORIG"; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T122-s11-dichiarato-ma-s10 s10 --esegui stadio11 originale;     rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S11'"
caso T123-s10-dichiarato-ma-s11 s11 --esegui stadio10 originale;     rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S10'"
caso T124-s11-cambiato orig --esegui originale stadio11 s11_ricompilato; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'non integra'
caso T125-s11-non-carica orig --esegui originale stadio11 fail_load_s11
rc_e 5; kld_e "completo $ORIG"; pci_ppt; kenv_come_prima
# il file congelato e' quello, ma il modulo caricato non espone l'oid di P3: verifica fallita, ritorno all'originale
caso T126-s11-senza-oid-p3 orig --esegui originale stadio11 s11_senza_p3
rc_e 5; kld_e "completo $ORIG"; out_ha "stadio11 caricato ma la verifica e' fallita"; out_ha 'oid(r110=1,h2=1,p3=0,fatal=1,opnd=1)'; pci_ppt; kenv_come_prima
# dichiarato stadio11 ma caricato senza P3 (uno stadio 10 sotto falso nome): STOP prima di agire
caso T127-s11-caricato-senza-p3 s11 --esegui stadio11 originale s11_senza_p3; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'p3=0'
caso T128-s10-s11 s10 --esegui stadio10 stadio11
rc_e 0; kld_e "completo $S11"; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T129-prova-s11 orig --prova originale stadio11;               rc_e 0; nessun_evento; nessun_diario; out_ha "kldload $S11"

echo "### originale = stadio 11 (02/11/2026) e stadio11-lapic"
# in /boot c'e' ancora il 149fa57e: lo strumento NON deve scambiare (ne' verso, ne' di ritorno)
caso T130-orig-vecchio orig --esegui originale stadio11-lapic orig_vecchio; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'originale non integro'
caso T131-orig-senza-p3 orig --esegui originale stadio11-lapic orig_senza_p3; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'p3=0'
caso T132-orig-s11l orig --esegui originale stadio11-lapic
rc_e 0; kld_e "completo $S11L"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T133-s11l-orig s11l --esegui stadio11-lapic originale
rc_e 0; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze
caso T134-s11l-dichiarato-ma-s11 s11 --esegui stadio11-lapic originale; rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S11L'"
caso T135-s11-dichiarato-ma-s11l s11l --esegui stadio11 originale;     rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S11'"
caso T136-s11l-cambiato orig --esegui originale stadio11-lapic s11l_ricompilato; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'non integra'
caso T137-s11l-non-carica orig --esegui originale stadio11-lapic fail_load_s11l
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T138-s11l-ritorno-non-carica s11l --esegui stadio11-lapic originale fail_load_orig
rc_e 6; kld_e nessuno; frozen_e 1; pci_libere; amdgpu_no; kenv_protetto
caso T139-s11-s11l s11 --esegui stadio11 stadio11-lapic
rc_e 0; kld_e "completo $S11L"; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T140-prova-s11l orig --prova originale stadio11-lapic;          rc_e 0; nessun_evento; nessun_diario; out_ha "kldload $S11L"; out_ha 'secondo scambio automatico stadio11-lapic -> originale'
caso T141-s11l-s11l s11l --esegui stadio11-lapic stadio11-lapic;     rc_e 4; nessun_evento
caso T142-s11l-s11i s11l --esegui stadio11-lapic stadio11-ipi
rc_e 0; kld_e "completo $S11I"; frozen_e 0; pci_ppt; amdgpu_no; kenv_come_prima; mai_senza_freeze; nessuna_asta
caso T143-s11i-orig s11i --esegui stadio11-ipi originale
rc_e 0; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T144-s11i-dichiarato-ma-s11l s11l --esegui stadio11-ipi originale; rc_e 4; nessun_evento; stop_nel_diario; out_ha "atteso 'completo $S11I'"
caso T145-s11i-cambiato s11l --esegui stadio11-lapic stadio11-ipi s11i_ricompilato; rc_e 4; nessun_evento; stop_nel_diario; out_ha 'non integra'
caso T146-s11i-non-carica s11l --esegui stadio11-lapic stadio11-ipi fail_load_s11i
rc_e 5; kld_e "completo $ORIG"; frozen_e 0; pci_ppt; kenv_come_prima; mai_senza_freeze
caso T147-prova-s11i s11l --prova stadio11-lapic stadio11-ipi;       rc_e 0; nessun_evento; nessun_diario; out_ha "kldload $S11I"
# l'oid di P3 resta VIETATO nello stadio 10 (e in ogni altra identita')
caso T130-s10-con-p3 s10 --esegui stadio10 originale oid_p3_finto;   rc_e 4; nessun_evento; stop_nel_diario

echo "### statico"
statico

echo
echo "SUMMARY: $PASS ok, $FAIL FAIL"
[ $FAIL = 0 ]
