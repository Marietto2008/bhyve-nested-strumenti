#!/bin/sh
# salva-contatori.sh -- claude 15/11/2026 (Fable 052 §3, «la lezione del 048»): accoda a dati-bhyve/esiti.md e a
# dati-bhyve/contatori.log tutti gli invarianti del modulo vmm caricato. Un contatore non letto prima dello scaricamento
# del modulo e' perso. Si chiama a fine sessione (vm0-13-qemu.sh) e prima di ogni kldunload (caldo-*.sh).
#   sh salva-contatori.sh "<motivo>"
PATH=/bin:/usr/bin:/sbin:/usr/sbin
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-bhyve
v() { sysctl -n "$1" 2>/dev/null || echo -; }
riga="$(date '+%d/%m %H:%M:%S') ${1:-(senza motivo)}: /boot vmm-restore.ko $(sha256 -q /boot/kernel/vmm-restore.ko 2>/dev/null | cut -c1-8);"
riga="$riga vpid01_viol=$(v hw.vmm.vmx.vpid01_invariant_viol) coperto=$(v hw.vmm.vmx.vpid01_coperto_da_invept)"
riga="$riga rete=$(v hw.vmm.vmx.vpid01_rete_invvpid) inrun_altro=$(v hw.vmm.vmx.vpid01_inrun_lastcpu_altro)"
riga="$riga slow_reflect=$(v hw.vmm.vmx.vpid01_invvpid_slow_reflect) vmcs_lib_attivo=$(v hw.vmm.vmx.vmcs_liberato_attivo)"
riga="$riga vmcs_clear_altra=$(v hw.vmm.vmx.vmcs_clear_altra_cpu) vmcs_pieno=$(v hw.vmm.vmx.vmcs_attivi_pieno)"
riga="$riga vmxon_doppio=$(v hw.vmm.vmx.nested_inv_vmxon_doppio) reset_in_vmx=$(v hw.vmm.vmx.nested_inv_reset_in_vmx)"
riga="$riga reset_inplace=$(v hw.vmm.reset_inplace) d3_break=$(v hw.vmm.vmx.nested_diag_d3_break) oprec=$(v hw.vmm.vmx.nested_diag_oprec)"
# 16/11 (diagnosi 059 par. 5.1): B1, rientro, sincronizzazione TSC
riga="$riga | vept_keep=$(v hw.vmm.vmx.vept_keep) rientro=$(v hw.vmm.vmx.vept_keep_rientro) partial=$(v hw.vmm.vmx.vept_keep_partial_invepts)"
riga="$riga retained=$(v hw.vmm.vmx.vept_keep_retained_leaves) invalidated=$(v hw.vmm.vmx.vept_keep_invalidated_leaves)"
riga="$riga full_fb=$(v hw.vmm.vmx.vept_keep_full_fallbacks) race_fb=$(v hw.vmm.vmx.vept_keep_scan_race_fallbacks) walk_zaps=$(v hw.vmm.vmx.vept_keep_walk_zaps)"
riga="$riga stale_root=$(v hw.vmm.vmx.vept_stale_root_enters) memgen_inv=$(v hw.vmm.vmx.vept_memgen_roots_invalidated)"
riga="$riga roots_matched=$(v hw.vmm.vmx.vept_invept_roots_matched) unmatched=$(v hw.vmm.vmx.vept_invept_roots_unmatched) kept=$(v hw.vmm.vmx.vept_invept_roots_kept) fallback=$(v hw.vmm.vmx.vept_invept_roots_fallback)"
riga="$riga rientro_valid=$(v hw.vmm.vmx.vept_rientro_validazioni) rientro_dannose=$(v hw.vmm.vmx.vept_rientro_voci_dannose) rientro_innocue=$(v hw.vmm.vmx.vept_rientro_voci_innocue)"
riga="$riga rientro_foglie_dannose=$(v hw.vmm.vmx.vept_rientro_foglie_dannose) rientro_non_validato=$(v hw.vmm.vmx.vept_rientro_non_validato)"
riga="$riga rientro_marcati=$(v hw.vmm.vmx.vept_rientro_marcati) rientro_fallback=$(v hw.vmm.vmx.vept_rientro_fallback)"
riga="$riga t_scan_ns=$(v hw.vmm.vmx.vept_t_scan_ns) scan_max_ns=$(v hw.vmm.vmx.vept_scan_max_ns) t_full_ns=$(v hw.vmm.vmx.vept_t_full_ns) t_partial_ns=$(v hw.vmm.vmx.vept_t_partial_ns)"
riga="$riga snap_alloc=$(v hw.vmm.vmx.vept_snap_allocate) snap_libere=$(v hw.vmm.vmx.vept_snap_libere) diag_mem=$(v hw.vmm.vmx.vept_diag_mem) z_nomem=$(v hw.vmm.vmx.vept_leaves_zapped_nomem) z_overflow=$(v hw.vmm.vmx.vept_leaves_zapped_overflow) z_nrng=$(v hw.vmm.vmx.vept_leaves_zapped_nrng) z_capacity=$(v hw.vmm.vmx.vept_leaves_zapped_capacity) full_fb2=$(v hw.vmm.vmx.vept_keep_full_fallbacks)"
riga="$riga vecchia_letture=$(v hw.vmm.vmx.vept_vecchia_letture) vecchia_esec=$(v hw.vmm.vmx.vept_vecchia_esecuzioni) vecchia_scr_ind=$(v hw.vmm.vmx.vept_vecchia_scritture_indirizzo) vecchia_scr_w=$(v hw.vmm.vmx.vept_vecchia_scritture_w_tolto) vecchia_scadute=$(v hw.vmm.vmx.vept_vecchia_scadute)"
# 16/11 (diagnosi 065 par. 2): accessi alle foglie vecchie per frame (a frame, b tolta, c wtolto, d innocua; pt / pd)
for c in frame tolta wtolto innocua; do riga="$riga scr_${c}=$(v hw.vmm.vmx.vept_vf_scr_${c}_pt)/$(v hw.vmm.vmx.vept_vf_scr_${c}_pd) let_${c}=$(v hw.vmm.vmx.vept_vf_let_${c}_pt)/$(v hw.vmm.vmx.vept_vf_let_${c}_pd)"; done
riga="$riga tsc_sync=$(v hw.vmm.vmx.tsc_sync) tsc_matched=$(v hw.vmm.vmx.tsc_sync_matched) tsc_new=$(v hw.vmm.vmx.tsc_sync_new) tsc_maxcorr=$(v hw.vmm.vmx.tsc_sync_maxcorr) tsc_off_viol=$(v hw.vmm.vmx.tsc_offset_viol)"
# 17/11 (Fable 067 par. 5.3.4): registratore delle hypercall: codici nella riga, anello in un file a parte
if sysctl -n hw.vmm.vmx.nested_hcall_reg >/dev/null 2>&1; then
	riga="$riga | hcall_codici=$(sysctl -n hw.vmm.vmx.nested_hcall_codici | tr ' ' ',') hcall_voci=$(v hw.vmm.vmx.nested_hcall_voci) hcall_senza_ritorno=$(v hw.vmm.vmx.nested_hcall_senza_ritorno)"
	A=$D/hcall-anello-$(date +%Y%m%d-%H%M%S).txt
	sysctl -n hw.vmm.vmx.nested_hcall_anello > $A 2>&1
	[ -s $A ] && riga="$riga hcall_anello=$(basename $A)"
fi
echo "$riga" >> $D/contatori.log
echo "- CONTATORI $riga" >> $D/esiti.md
echo "$riga"
