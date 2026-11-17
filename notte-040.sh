#!/bin/sh
# notte-040.sh -- Claude 14/11/2026, verifiche della diagnosi 040 di Fable (§5 punti 3-5), con la correzione D3 accesa
# (modulo 2b50abb0, hw.vmm.vmx.nested_d3_fix=1). In fila:
#   A) una tempesta sotto Hyper-V Manager (tempesta-hyperv.sh 1): vpid01_slowpath_claim per episodio, da confrontare con
#      WHPX (~1 ogni 660);
#   B) un giro con l'amplificatore da 1000 us (ciclo-amp.sh 1, AMP_US=1000): il thread appeso della 031 c'e' ancora?
#   C) ciclo sulla via WSL con svuotamento (ciclo-bhyve.sh 16): criterio principale vpid01_invariant_viol fermo,
#      secondario 16 giri senza panic.
# Contatori prima/dopo ogni fase in ../dati-bhyve/notte-040-<ora>.txt. FASI=ABC (di base) sceglie le fasi da fare.
set -u
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
S=$D/strumenti
L=$D/dati-bhyve/notte-040-$(date +%Y%m%d-%H%M%S).txt
foto() { echo "$(date +%T) $1: $(for v in nested_d3_fix vpid01_slowpath_claim vpid01_slowpath_noclaim vpid01_invariant_viol nested_diag_pfrec_e0 nested_diag_pfrec_pf_fetch nested_diag_pfrec_pf_data nested_diag_amp_applied; do printf '%s=%s ' $v $(sysctl -n hw.vmm.vmx.$v); done)" | tee -a $L; }
[ "$(sysctl -n hw.vmm.vmx.nested_d3_fix)" = 1 ] || { echo "STOP: nested_d3_fix non e' 1" | tee -a $L; exit 4; }
foto "inizio"
F=${FASI:-ABC}
case $F in *A*)
echo "$(date +%T) FASE A: Hyper-V Manager, 1 tempesta" | tee -a $L
sh $S/tempesta-hyperv.sh 1 >> $L 2>&1
foto "fine A";; esac
case $F in *B*)
echo "$(date +%T) FASE B: amplificatore 1000 us, 1 giro (via WSL)" | tee -a $L
AMP_US=1000 sh $S/ciclo-amp.sh 1 >> $L 2>&1
sudo -n sysctl hw.vmm.vmx.nested_diag_amp_us=0 >/dev/null
foto "fine B";; esac
case $F in *C*)
echo "$(date +%T) FASE C: via WSL con svuotamento, ${GIRI_C:-16} giri" | tee -a $L
sh $S/ciclo-bhyve.sh ${GIRI_C:-16} >> $L 2>&1
foto "fine C";; esac
echo "$(date +%T) FINE notte-040" | tee -a $L
