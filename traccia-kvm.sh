#!/bin/sh
# traccia-kvm.sh [secondi] -- Claude 09/11/2026. DA LANCIARE CON sudo (i tracepoint di KVM vogliono root).
# Registra per [secondi] (di base 1800) solo gli eventi RARI di KVM legati al panic LAPIC, filtrati nel kernel:
#   kvm_nested_vmexit_inject uscite 44 (APIC access) e 2 (triple fault) riflesse a Hyper-V
#   kvm_nested_vmenter       ingressi in cui Hyper-V INIETTA un #PF nell'L2 (event_inj = vettore 14, eccezione)
#   kvm_nested_vmenter_failed  ingressi nell'L2 rifiutati
# 10/11: tolto kvm_page_fault su 0xfee00000: prendeva soprattutto il LAPIC di Windows L1 (467 MB di .dat,
# 15 GB di testo il 09/11). Le uscite 44 sono milioni se Hyper-V le usa: la prima traccia le ha gia' contate,
# qui servono solo per vedere se ci sono (con -vmx-apicv-xapic devono essere 0), quindi solo le scritture
# all'Initial Count (qualificazione 0x1380).
# Esito: ../dati-kvm/traccia-<ora>.dat (+ .txt leggibile). Campi: arch/x86/kvm/trace.h di 6.8.
set -u
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-kvm
T=$(date +%Y%m%d-%H%M%S)
trace-cmd record -o $D/traccia-$T.dat \
	-e kvm:kvm_nested_vmexit_inject -f '(exit_code == 44 && exit_info1 == 0x1380) || exit_code == 2' \
	-e kvm:kvm_nested_vmenter -f 'event_inj == 0x80000b0e || event_inj == 0x8000030e' \
	-e kvm:kvm_nested_vmenter_failed \
	sleep ${1:-1800}
trace-cmd report -i $D/traccia-$T.dat > $D/traccia-$T.txt 2>&1
chmod 644 $D/traccia-$T.dat $D/traccia-$T.txt
ls -l $D/traccia-$T.dat $D/traccia-$T.txt
echo "eventi:"; awk '{for (i = 1; i <= NF; i++) if ($i ~ /^kvm_/) { n[$i]++; break }} END {for (k in n) print "  " k, n[k]}' $D/traccia-$T.txt
echo "file: $D/traccia-$T.txt"
