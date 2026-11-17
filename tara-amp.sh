#!/bin/sh
# tara-amp.sh [attacca] -- Claude 11/11/2026: giro di taratura dell'amplificatore (Fable 030 §3.1). Lancia
# tempesta-bhyve svuota (o, con «attacca», usa quella gia' in corso), ATTENDE che la tempesta sia davvero partita
# (episodi E0 > 300.000: all'avvio di Windows la pulizia di WSL puo' durare minuti), poi gradini di ritardo
# 0 (base), 100, 200, 500 us su ogni episodio, 3 minuti l'uno, con fotografie di nested_diag_e0_durata; poi amp a 0.
# 11/11 23:23: la prima versione partiva a tempo fisso (+240 s) e misurava prima della tempesta.
set -u
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
O=$D/dati-bhyve/tara-amp-$(date +%Y%m%d-%H%M%S).txt
s() { sysctl -n hw.vmm.vmx.$1; }
foto() { echo "== $(date +%T) amp_us=$(s nested_diag_amp_us) applicati=$(s nested_diag_amp_applied) e0=$(s nested_diag_pfrec_e0) ilen=$(s nested_diag_e0c_ilen) fermo=$(s nested_diag_e0c_fermo) altro=$(s nested_diag_e0c_altro) senza_cr3=$(s nested_diag_e0c_senza_cr3) pf=$(s nested_diag_pfrec_pf_fetch)/$(s nested_diag_pfrec_pf_data)" >> $O; s nested_diag_e0_durata >> $O; }
vivo() { pgrep -qf '^sh [^ ]*tempesta-bhyve.sh'; }
sudo -n sysctl hw.vmm.vmx.nested_diag_amp_us=0 hw.vmm.vmx.nested_diag_amp_every=1 >/dev/null
[ "${1:-}" = attacca ] || { sh $D/strumenti/tempesta-bhyve.sh svuota > $D/dati-bhyve/uscita-tara-amp.txt 2>&1 & }
sleep 5
until [ $(s nested_diag_pfrec_e0) -gt 300000 ]; do vivo || { echo "tempesta finita prima di partire" >> $O; echo $O; exit 1; }; sleep 5; done
foto
for us in 0 100 200 500; do
	vivo || break
	sudo -n sysctl hw.vmm.vmx.nested_diag_amp_us=$us >/dev/null
	sleep 180; foto
done
sudo -n sysctl hw.vmm.vmx.nested_diag_amp_us=0 >/dev/null
while vivo; do sleep 10; done
foto
echo "== giro: $(/usr/bin/grep -a panic $(ls -t $D/dati-bhyve/giro-*.txt | head -1) | tail -1)" >> $O
echo $O
