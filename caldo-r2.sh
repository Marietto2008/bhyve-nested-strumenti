#!/bin/sh
# caldo-r2.sh -- claude 15/11/2026. Cambio A CALDO del vmm caricato (01ca6c86) con quello gia' installato in
# /boot/kernel/vmm-restore.ko (R2, 286f16da), con le protezioni di nested-work/caldo/mc-logica.sh (#117/#118):
# kenv boot_safe=YES (nessun nuovo devmatch), devmatch_blocklist += moduli candidati per i dispositivi ppt, barriera
# sui devmatch gia' partiti, `devctl freeze` attorno a kldunload/kldload (i driver nativi non agganciano i ppt
# liberati; al thaw vince ppt), thaw SOLO con un modulo caricato, verifica dei ppt, kenv ripristinato.
# Non si usa modulo-caldo.sh perche' il suo «originale» (149fa57e) e lo sha di loader.conf sono di ottobre.
#   sh caldo-r2.sh --prova     sola lettura: controlli e sequenza
#   sh caldo-r2.sh --esegui    (consenso dell'utente 15/11: «installalo», «si» al cambio a caldo)
# Uscita: 0 ok | 4 STOP, nulla cambiato | 5 nuovo non caricato, tornato a 01ca6c86 | 6 EMERGENZA (freeze lasciato)
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
NUOVO=/boot/kernel/vmm-restore.ko
NUOVO_SHA=286f16dae2221484960a6a2bc65931d98bd079d27b71bb348d2f6a5971acc167
VECCHIO=/boot/kernel/vmm-restore.ko.01ca6c86
VECCHIO_SHA=01ca6c86f6f821b7c48caf85ec6906d4a47400eb8e7c6de2553a4f3fee263c45
MODO=${1:-}
case "$MODO" in --prova|--esegui) ;; *) echo "uso: $0 --prova|--esegui"; exit 4;; esac
dice() { echo "$(date '+%H:%M:%S') $*"; }
stop() { dice "STOP: $*"; exit 4; }
ppt_foto() { pciconf -l | awk '/^ppt[0-9]+@/ { split($1, a, "@"); sub(/:$/, "", a[2]); print a[2], a[1] }' | sort; }

# --- controlli, sola lettura
[ "$(id -u)" = 0 ] || stop "serve root"
kldstat -n vmm-restore.ko >/dev/null 2>&1 || stop "vmm-restore.ko non caricato"
sysctl -n hw.vmm.vmx.vpid01_invariant_viol >/dev/null 2>&1 || stop "il caricato non sembra 01ca6c86 (manca vpid01_invariant_viol)"
sysctl -n hw.vmm.reset_inplace >/dev/null 2>&1 && stop "R2 risulta gia' caricato (hw.vmm.reset_inplace esiste)"
[ "$(sha256 -q $NUOVO)" = "$NUOVO_SHA" ] || stop "$NUOVO non e' R2 286f16da"
[ "$(sha256 -q $VECCHIO)" = "$VECCHIO_SHA" ] || stop "$VECCHIO non e' 01ca6c86"
[ "$(sysctl -n hw.vmm.iommu.initialized 2>/dev/null)" = 0 ] || stop "hw.vmm.iommu.initialized != 0: c'e' stata una VM con passthrough"
ps -ax -o comm= | grep -qiE 'bhyve|qemu-system' && stop "processo bhyve/qemu vivo"
[ -z "$(ls /dev/vmm 2>/dev/null)" ] || stop "nodi in /dev/vmm: $(ls /dev/vmm | tr '\n' ' ')"
FOTO0=$(ppt_foto); N=$(echo "$FOTO0" | grep -c .)
dice "dispositivi ppt ($N): $(echo "$FOTO0" | tr '\n' ';')"
BLOCCA=$(for u in $(echo "$FOTO0" | awk '{sub(/^ppt/, "", $2); print $2}'); do
	devmatch -p "? at $(sysctl -n dev.ppt.$u.%location 2>/dev/null) $(sysctl -n dev.ppt.$u.%pnpinfo 2>/dev/null) on $(sysctl -n dev.ppt.$u.%parent 2>/dev/null)" 2>/dev/null
done | sed 's/\.ko$//' | sort -u | tr '\n' ' ' | sed 's/ $//')
dice "moduli che devmatch proporrebbe per i ppt: '${BLOCCA:-nessuno}'"
for m in $BLOCCA; do kldstat -n "$m.ko" >/dev/null 2>&1 && stop "candidato $m gia' caricato"; done
BS_C=0; kenv -q boot_safe >/dev/null 2>&1 && { BS_C=1; BS_V=$(kenv -q boot_safe); }
BL_C=0; kenv -q devmatch_blocklist >/dev/null 2>&1 && { BL_C=1; BL_V=$(kenv -q devmatch_blocklist); }
dice "kenv prima: boot_safe=$([ $BS_C = 1 ] && echo "'$BS_V'" || echo assente) devmatch_blocklist=$([ $BL_C = 1 ] && echo "'$BL_V'" || echo assente)"
dice "sequenza: kenv boot_safe=YES + blocklist, barriera, devctl freeze, kldunload, kldload $NUOVO (ripiego $VECCHIO), devctl thaw, verifica, kenv ripristinato"
[ "$MODO" = --prova ] && { dice "prova: nulla cambiato"; exit 0; }

kenv_ripristina() {
	if [ $BS_C = 1 ]; then kenv "boot_safe=$BS_V" >/dev/null; else kenv -u boot_safe >/dev/null 2>&1; fi
	if [ $BL_C = 1 ]; then kenv "devmatch_blocklist=$BL_V" >/dev/null; else kenv -u devmatch_blocklist >/dev/null 2>&1; fi
	dice "kenv ripristinato: boot_safe=$(kenv -q boot_safe 2>/dev/null || echo assente) devmatch_blocklist=$(kenv -q devmatch_blocklist 2>/dev/null || echo assente)"
}
# --- protezioni
kenv boot_safe=YES >/dev/null || stop "kenv boot_safe non impostato"
if [ -n "$BLOCCA" ]; then kenv "devmatch_blocklist=$(echo "${BL_V:-} $BLOCCA" | sed 's/^ //')" >/dev/null || { kenv_ripristina; stop "blocklist non impostata"; }; fi
i=0; while ps -ax -o command= | grep -E '/etc/rc\.d/devmatch|service devmatch|(^|[ /])devmatch -' | grep -qv grep; do
	[ $i -ge 15 ] && { kenv_ripristina; stop "devmatch ancora attivo dopo 15 s"; }; sleep 1; i=$((i + 1)); done
[ "$(kenv -q boot_safe)" = YES ] || { kenv_ripristina; stop "boot_safe non riletto"; }
dice "barriera ok (${i}s); boot_safe=YES; devmatch_blocklist='$(kenv -q devmatch_blocklist 2>/dev/null)'"
# --- scambio
# 15/11 (Fable 052 §3): gli invarianti del modulo che sta per essere scaricato, prima che vadano persi
sh /mnt/linuxulator2/vm/confronto-kvm-bhyve/strumenti/salva-contatori.sh "prima di kldunload ($0)" >/dev/null
devctl freeze || { kenv_ripristina; stop "devctl freeze fallito"; }
dice "freeze"
if ! kldunload -n vmm-restore.ko; then
	devctl thaw; kenv_ripristina; stop "kldunload fallito: modulo vecchio ancora caricato, thaw fatto"
fi
dice "scaricato 01ca6c86"
ESITO=0
if kldload $NUOVO; then dice "caricato R2 $NUOVO"
elif kldload $VECCHIO; then dice "kldload di R2 FALLITO: ricaricato 01ca6c86"; ESITO=5
else dice "EMERGENZA: nessun modulo si carica; freeze LASCIATO, nessun thaw a mano prima di controllare"; exit 6
fi
devctl thaw && dice "thaw" || { dice "ANOMALIA: thaw rifiutato"; ESITO=6; }
sleep 2
# --- verifica
FOTO1=$(ppt_foto)
if [ "$FOTO1" = "$FOTO0" ]; then dice "ppt come prima ($N)"; else dice "ANOMALIA ppt: prima '$(echo "$FOTO0" | tr '\n' ';')' dopo '$(echo "$FOTO1" | tr '\n' ';')'"; ESITO=6; fi
for m in $BLOCCA; do kldstat -n "$m.ko" >/dev/null 2>&1 && { dice "ANOMALIA: caricato $m"; ESITO=6; }; done
if [ $ESITO = 0 ]; then
	sysctl -n hw.vmm.reset_inplace >/dev/null 2>&1 && dice "R2 attivo: hw.vmm.reset_inplace=$(sysctl -n hw.vmm.reset_inplace), nested_inv_vmxon_doppio=$(sysctl -n hw.vmm.vmx.nested_inv_vmxon_doppio), nested_inv_reset_in_vmx=$(sysctl -n hw.vmm.vmx.nested_inv_reset_in_vmx)" || { dice "ANOMALIA: hw.vmm.reset_inplace assente"; ESITO=6; }
fi
kenv_ripristina
dice "esito $ESITO"
exit $ESITO
