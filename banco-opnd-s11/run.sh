#!/bin/sh
# run.sh (banco-opnd-s11) -- Claude 01/11/2026, stadio 11 (P3, parere Astra #158 D1/R1). Lo stesso banco dell'operando
# VMX dello stadio 10, sulle funzioni VERE del clone freebsd-s11-nested (vm_run col flag CONTESO, _vm_copy_setup col
# budget, nested_operand_copy e i suoi 8 gestori con NOPND_CONTESO), con le pagine contese aggiunte (sezione S11).
# Verifica: 0 errori sullo stadio 11; sulla griglia dello stadio 10 esiti IDENTICI caso per caso (regressione); i
# mutanti dello stadio 10 ancora presi; i mutanti dello stadio 11 presi; sanitizer.
# Uso: run.sh <cartella nuova in collaudi>
. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh
W=/mnt/linuxulator2/vm/nested-work
B=$W/banco-opnd-s11
B10=$W/banco-opnd-s10
S11=$W/freebsd-s11-nested/sys/amd64/vmm
O=${1:?cartella}
case "$O" in $COLLAUDI/*) ;; *) echo "uscita fuori da $COLLAUDI"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste"; exit 2; }
mkdir -p "$O" || exit 1
CC="cc -std=gnu11 -Wall -Werror=switch -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable"
FV="vm_segment_name vm_set_register vm_restart_instruction vm_fatal_latch vcpu_init vm_handle_inst_emul vm_copy_teardown _vm_copy_setup vm_copy_setup vm_copy_setup_budget vm_copyin vm_copyout vm_segnala_conteso vm_run"
FN="--opzionali enum:nested_opnd nested_seg_last_ok blocco:static~const~struct~{~uint32_t~enc;~uint32_t~fl;~}~shv_fields shv_fault shvmcs_pull nested_eptp_ok nested_inv_esposta nested_insn_guard nested_vmfail_invalid nested_advance_rip nested_canonical nested_operand_latch nested_operand_gpa_at nested_operand_gpa nested_operand_copy nested_read_operand_u64 nested_operand_fatale nested_operand_conteso nested_fixed_ok nested_vmxon nested_vmclear nested_vmptrld nested_vmptrst nested_reg_operando nested_vmread nested_vmwrite nested_invvpid nested_invept vmx_nested_exit"
FI="blocco:static~uint64_t~size2mask vie_size2mask vie_calculate_gla"
FV10="vm_segment_name vm_set_register vm_restart_instruction vm_fatal_latch vcpu_init vm_handle_inst_emul vm_copy_teardown vm_copy_setup vm_copyin vm_copyout vm_run"
FN10=$(echo "$FN" | sed 's/ nested_operand_conteso//')
nf=0
grep -q '^[[:space:]]*\.nested_exit[[:space:]]*= vmx_nested_exit,' $S11/intel/vmx.c || { echo "vmx.c: .nested_exit non e' vmx_nested_exit"; nf=$((nf+1)); }
FINALE=s11
rinomina() {	# shvmcs_pull vera -> shvmcs_pull_vera (lo stub la avvolge per contare)
	python3 - "$1" <<'FINE_PY_RINOMINA_S11'
import sys
s = open(sys.argv[1]).read()
v = '\nshvmcs_pull(struct vmx_vcpu *vcpu)\n'
assert s.count(v) == 1, 'definizione di shvmcs_pull: %d' % s.count(v)
open(sys.argv[1], 'w').write(s.replace(v, '\nshvmcs_pull_vera(struct vmx_vcpu *vcpu)\n'))
FINE_PY_RINOMINA_S11
}
prova() {	# prova <nome> <file funzioni>  -> esito in $O/<nome>/esito.txt, ritorno: 0 ok, 1 errati, 2 compilazione
	mkdir -p "$O/$1"
	cp "$B/stub.h" "$B/stub-nested.h" "$B/banco.c" "$O/$1/"; cp "$2" "$O/$1/funzioni.inc"
	$CC -I"$O/$1" -o "$O/$1/banco" "$O/$1/banco.c" > "$O/$1/cc.txt" 2>&1 || return 2
	"$O/$1/banco" "$1" > "$O/$1/esito.txt" 2>&1
}
{ python3 $B/estrai.py $S11/vmm.c $FV && python3 $B/estrai.py $S11/vmm_instruction_emul.c $FI && python3 $B/estrai.py $S11/intel/vmx_nested.c $FN; } > "$O/fn-s11.inc" 2>&1 || { echo "estrazione s11 fallita"; grep '#error' "$O/fn-s11.inc"; exit 1; }
grep -q 'vm_copy_setup_budget(vcpu->vcpu' "$O/fn-s11.inc" || { echo "l'estratto non e' lo stadio 11"; exit 1; }
rinomina "$O/fn-s11.inc" || exit 1
prova s11 "$O/fn-s11.inc"; r=$?
[ $r = 2 ] && { echo "COMPILAZIONE FALLITA s11"; head -20 "$O/s11/cc.txt"; exit 1; }
tail -2 "$O/s11/esito.txt"
n=$(grep -c '  ERRATO ' "$O/s11/esito.txt")
[ $r = 0 ] && [ "$n" = 0 ] && echo "  ok      stadio 11: 0 errori" || { echo "  ERRATO  stadio 11 con $n errori:"; grep '  ERRATO ' "$O/s11/esito.txt" | head -20; nf=$((nf+1)); }
grep -q 'osservato PANIC_HOST\|osservato SALTO_SILENZIOSO' "$O/s11/esito.txt" && { echo "  ERRATO  PANIC_HOST o SALTO_SILENZIOSO"; nf=$((nf+1)); }

# regressione: la griglia dello stadio 10 (banco e funzioni dello stadio 10 congelato) contro lo stadio 11, caso per caso
mkdir -p "$O/s10"
{ python3 $B10/estrai.py $W/logs/r6r3-160/stadi/9-EA/vmm.c $FV10 && python3 $B10/estrai.py $W/logs/s10/stadi/7-K11/vmm_instruction_emul.c $FI && python3 $B10/estrai.py $W/logs/s10/stadi/7-K11/vmx_nested.c $FN10; } > "$O/fn-s10.inc" 2>&1 || { echo "  ERRATO  estrazione s10 fallita"; nf=$((nf+1)); }
rinomina "$O/fn-s10.inc"
cp "$B10/stub.h" "$B10/stub-nested.h" "$B10/banco.c" "$O/s10/"; cp "$O/fn-s10.inc" "$O/s10/funzioni.inc"
if $CC -I"$O/s10" -o "$O/s10/banco" "$O/s10/banco.c" > "$O/s10/cc.txt" 2>&1; then
	"$O/s10/banco" s10 -v > "$O/v-s10.txt" 2>&1; "$O/s11/banco" s11 -v > "$O/v-s11.txt" 2>&1
	python3 - "$O/v-s10.txt" "$O/v-s11.txt" > "$O/regressione-10-11.txt" <<'FINE_PY_REGR_S11'
import sys, re
def casi(f):
    return [re.sub(r'^  (ok     |ERRATO ) ', '', l.rstrip('\n')) for l in open(f) if re.match(r'  (ok     |ERRATO ) \[', l)]
a, b = casi(sys.argv[1]), casi(sys.argv[2])
diversi = [(x, y) for x, y in zip(a, b) if x != y]
print('stadio 10: %d casi; stadio 11: %d casi (%d in piu\', sezione S11); diversi sui primi %d: %d' % (len(a), len(b), len(b) - len(a), len(a), len(diversi)))
for x, y in diversi[:20]:
    print('  10: %s\n  11: %s' % (x, y))
sys.exit(1 if diversi or len(b) <= len(a) else 0)
FINE_PY_REGR_S11
	if [ $? = 0 ]; then echo "  ok      regressione: $(head -1 $O/regressione-10-11.txt)"; else echo "  ERRATO  regressione:"; head -12 "$O/regressione-10-11.txt"; nf=$((nf+1)); fi
else echo "  ERRATO  compilazione dello stadio 10 fallita"; head -5 "$O/s10/cc.txt"; nf=$((nf+1)); fi

# mutanti sullo stadio FINALE (quelli dello stadio 9 riallineati a K5/K3, poi i nuovi dello stadio 10): ognuno deve far fallire il banco con l'osservazione giusta (o la compilazione, se dichiarato);
# "fallire" = una riga ERRATO in piu' rispetto ai residui, con l'osservazione attesa
mut() {	# mut <nome> <atteso: testo nella riga ERRATO | COMPILAZIONE> <file: vmm|nested> <vecchio> <nuovo>
	python3 - "$O/fn-$FINALE.inc" "$O/mut-$1.inc" "$4" "$5" <<'FINE_PY_MUTOPND'
import sys
s = open(sys.argv[1]).read()
if s.count(sys.argv[3]) < 1:
    sys.exit('testo del mutante assente: ' + sys.argv[3][:60])
open(sys.argv[2], 'w').write(s.replace(sys.argv[3], sys.argv[4], 1))
FINE_PY_MUTOPND
	[ -s "$O/mut-$1.inc" ] || { echo "  ERRATO  mutante $1: non generato"; nf=$((nf+1)); return; }
	prova "mut-$1" "$O/mut-$1.inc"; r=$?
	if [ "$2" = COMPILAZIONE ]; then
		if [ $r = 2 ] && grep -q 'Werror,-Wswitch\|-Werror=switch\|enumeration value' "$O/mut-$1/cc.txt"; then echo "  ok      mutante $1 preso dal compilatore (-Werror=switch)"
		else echo "  ERRATO  mutante $1: atteso rifiuto del compilatore, uscita $r"; nf=$((nf+1)); fi; return
	fi
	if [ $r = 2 ]; then echo "  ERRATO  mutante $1: compilazione fallita"; head -5 "$O/mut-$1/cc.txt"; nf=$((nf+1))
	elif [ $r = 0 ]; then echo "  ERRATO  mutante $1 NON preso"; nf=$((nf+1))
	elif grep '  ERRATO ' "$O/mut-$1/esito.txt" | grep -q -- "$2"; then echo "  ok      mutante $1 preso ($(grep -c '  ERRATO ' $O/mut-$1/esito.txt) casi): $(grep '  ERRATO ' $O/mut-$1/esito.txt | grep -m1 -- "$2" | sed 's/.*: atteso/atteso/' | cut -c1-110)"
	else echo "  ERRATO  mutante $1 preso ma non per \"$2\": $(grep -m1 '  ERRATO ' $O/mut-$1/esito.txt | cut -c1-140)"; nf=$((nf+1)); fi
}
mut ritorno_0_su_host_fatale 'FALSO_FAIL_STOP' n '	(void)vcpu;
	return (ENOTRECOVERABLE);' '	(void)vcpu;
	return (0);'
mut gp_inventato_su_efault 'atteso FATALE/4, osservato ECCEZIONE#13' n '			(void)nested_operand_latch(vcpu, error,
			    VM_FATAL_NESTED_OPERAND, pz[k].gla, VM_FATAL_V_GLA);
			return (NOPND_HOST_FATALE);' '			vm_inject_gp(vcpu->vcpu);
			return (NOPND_INIETTATO);'
mut ripartenza_su_efault 'GIRO_ILLIMITATO' n '			(void)nested_operand_latch(vcpu, error,
			    VM_FATAL_NESTED_OPERAND, pz[k].gla, VM_FATAL_V_GLA);
			return (NOPND_HOST_FATALE);' '			vm_restart_instruction(vcpu->vcpu);
			return (NOPND_INIETTATO);'
mut latch_senza_rollback 'FATALE_SENZA_ROLLBACK' n '	vm_restart_instruction(vcpu->vcpu);	/* vCPU FROZEN: nextrip = RIP */' ''
mut bogus_mancante 'KASSERT' n '	vme->exitcode = VM_EXITCODE_BOGUS;
	vme->inst_length = 0;
	atomic_add_long(&nested_operand_fatal, 1);' '	atomic_add_long(&nested_operand_fatal, 1);'
mut latch_sul_pf_autentico 'atteso ECCEZIONE#14, osservato FALSO_HOST_FATALE' n '		if (fault) {			/* #PF iniettato da vm_gla2gpa */
			vm_copy_teardown(ci, nitems(ci));
			return (NOPND_INIETTATO);' '		if (fault) {			/* #PF iniettato da vm_gla2gpa */
			vm_copy_teardown(ci, nitems(ci));
			(void)nested_operand_latch(vcpu, EFAULT,
			    VM_FATAL_NESTED_OPERAND, pz[k].gla, VM_FATAL_V_GLA);
			return (NOPND_HOST_FATALE);'
mut senza_teardown 'RISORSE' n '	vm_copy_teardown(ci, nitems(ci));
	return (NOPND_OK);' '	return (NOPND_OK);'
mut seconda_pagina_non_tradotta 'EFFETTO_ERRATO' v '		gla += n;
		nused++;' '		gla += 0;
		nused++;'
mut vmread32_otto_byte 'EFFETTO_ERRATO' n '	len = vcpu->nested->exit_paging.cpu_mode == CPU_MODE_64BIT ? 8 : 4;
	if (len == 4)
		val &= 0xffffffffULL;' '	len = 8;'
mut esito_prima_della_copia 'EFFETTO_PARZIALE' n '	cur = n->current_vmcs12;		/* VMCS12_GPA_NONE se nessuno */' '	cur = n->current_vmcs12;		/* VMCS12_GPA_NONE se nessuno */
	nested_vmx_result(vcpu, VMXR_SUCCEED);'
mut k3_assente 'K3_BYPASS' v '	if (vcpu->fatal.errno_orig != 0)
		return (ENOTRECOVERABLE);' ''
mut sonda_doppia 'FATALE_SONDE' n '	SDT_PROBE5(vmm, vmx, nested, opndfatal, vcpu->vcpuid, stadio, err,' '	SDT_PROBE5(vmm, vmx, nested, opndfatal, vcpu->vcpuid, stadio, err,
	    vme->rip, 0);
	SDT_PROBE5(vmm, vmx, nested, opndfatal, vcpu->vcpuid, stadio, err,'
mut getdesc_silenzioso 'atteso FATALE/5, osservato SALTO_SILENZIOSO' n '		(void)nested_operand_latch(vcpu, error, VM_FATAL_NESTED_SEGDESC, 0, 0);
		return (NOPND_HOST_FATALE);' '		return (NOPND_INIETTATO);'
mut m128_tipo_dopo_lettura 'M128' n '	if (type > 3 || (cap & (1ULL << (40 + type))) == 0) {
		nested_vmx_result(vcpu, VMXERR_INVALID_OPERAND_TO_INVEPT_INVVPID);
		nested_advance_rip(vcpu);
		return (0);
	}
	switch (nested_operand_copy(vcpu, VM_PROT_READ, q, sizeof(q))) {
	case NOPND_OK:
		break;
	case NOPND_INIETTATO:
		return (0);
	case NOPND_HOST_FATALE:
		return (nested_operand_fatale(vcpu));
	case NOPND_CONTESO:
		return (nested_operand_conteso(vcpu));
	}' '	switch (nested_operand_copy(vcpu, VM_PROT_READ, q, sizeof(q))) {
	case NOPND_OK:
		break;
	case NOPND_INIETTATO:
		return (0);
	case NOPND_HOST_FATALE:
		return (nested_operand_fatale(vcpu));
	case NOPND_CONTESO:
		return (nested_operand_conteso(vcpu));
	}
	if (type > 3 || (cap & (1ULL << (40 + type))) == 0) {
		nested_vmx_result(vcpu, VMXERR_INVALID_OPERAND_TO_INVEPT_INVVPID);
		nested_advance_rip(vcpu);
		return (0);
	}'
mut gla_non_valida_dichiarata 'FATALE_DIAGNOSI' n '			    VM_FATAL_NESTED_OPERAND, pz[k].gla, VM_FATAL_V_GLA);
			return (NOPND_HOST_FATALE);' '			    VM_FATAL_NESTED_OPERAND, 0, VM_FATAL_V_GLA);
			return (NOPND_HOST_FATALE);'
mut vmread32_registro_non_troncato 'EFFETTO_ERRATO(VMREAD registro)' n '	if (len == 4)
		val &= 0xffffffffULL;

	if ((info >> 10) & 0x1) {' '
	if ((info >> 10) & 0x1) {'
mut vmwrite32_registro_non_troncato 'EFFETTO_ERRATO(VMWRITE registro)' n '		val = nested_reg_operando(vcpu, (info >> 3) & 0xf);' '		val = vmx_get_guest_reg(vcpu, (info >> 3) & 0xf);'
mut nessuna_pretraduzione 'atteso ECCEZIONE#14, osservato FATALE/4' n '	for (k = 0; npz > 1 && k < npz; k++) {' '	for (k = 0; 0 && k < npz; k++) {'
mut dispatch_vmptrst_ritorna_0 'FALSO_FAIL_STOP' n '	case EXIT_REASON_VMPTRST:	return (nested_vmptrst(vcpu));' '	case EXIT_REASON_VMPTRST:	(void)nested_vmptrst(vcpu); return (0);'
mut prefisso_senza_statistiche 'PREFISSO' n '	if (vcpu->nested != NULL)
		nested_stats_flush(vcpu);' ''
mut r8_guardia_senza_vmptrld 'atteso ECCEZIONE#13, osservato ESEGUITA' n '	case EXIT_REASON_VMPTRLD:
	case EXIT_REASON_VMPTRST:' '	case EXIT_REASON_VMPTRST:'
mut r8_guardia_senza_vmx_attiva 'atteso ECCEZIONE#6' n '	if (!vcpu->nested->vmxon) {
		vm_inject_ud(vcpu->vcpu);
		return (true);
	}
	if (vcpu->nested->exit_paging.cpl != 0) {' '	if (vcpu->nested->exit_paging.cpl != 0) {'
mut r8_guardia_dopo_shvmcs 'PREFISSO' n '	/* #162 R8: VMX non attiva e CPL > 0, prima di qualunque effetto */
	if (vcpu->nested != NULL && nested_insn_guard(vcpu, reason))
		return (0);
' ''
mut eptp_non_controllato 'atteso ESEGUITA_VMFAIL, osservato ESEGUITA' n '		if (!nested_eptp_ok(cap, eptp)) {' '		if (0) {'
mut eptp_vmfail_ma_invalida 'EFFETTO_PARZIALE(stato)' n '		if (!nested_eptp_ok(cap, eptp)) {' '		if (!nested_eptp_ok(cap, eptp)) {
			{ int kk; (void)vmx_vept_invept(vcpu, type, eptp, &kk); }'
mut w4g_oltre_4gb 'OLTRE_4G' n '	if (paging.cpu_mode != CPU_MODE_64BIT && gla0 + len > (1ULL << 32)) {' '	if (0) {'
mut fsgs_base_ignorata 'osservato' n '	} else {
		segbase = desc->base;
	}' '	} else {
		segbase = 0;
	}'
mut expand_down_invertito 'atteso' n '	if ((SEG_DESC_TYPE(d->access) & 0xC) == 0x4)	/* dati expand-down */' '	if ((SEG_DESC_TYPE(d->access) & 0xC) != 0x4)	/* dati expand-down */'
mut ultimo_byte_non_controllato 'atteso ECCEZIONE#13' n '	if (paging.cpu_mode != CPU_MODE_64BIT &&
	    !nested_seg_last_ok(&desc, ea + len - 1))
		goto segfault;' ''
mut gla_troncato_a_32_bit 'osservato' n '	    &gla0) != 0)
		goto segfault;' '	    &gla0) != 0)
		goto segfault;
	if (addrsize == 4)
		gla0 &= 0xffffffffULL;'
mut secondo_pezzo_non_copiato 'EFFETTO_ERRATO' n '	for (k = 0, fatto = 0; k < npz;' '	for (k = 0, fatto = 0; k < 1;'
mut copia_prima_dell_ultimo_setup 'EFFETTO_PARZIALE' n '		if (fault) {			/* #PF iniettato da vm_gla2gpa */
			vm_copy_teardown(ci, nitems(ci));
			return (NOPND_INIETTATO);
		}
	}' '		if (fault) {			/* #PF iniettato da vm_gla2gpa */
			vm_copy_teardown(ci, nitems(ci));
			return (NOPND_INIETTATO);
		}
		if (k == 0 && (prot & VM_PROT_WRITE))
			vm_copyout(buf, &ci[0], pz[0].len);
	}'
mut eptp_capacita_fisiche 'atteso ESEGUITA_VMFAIL, osservato ESEGUITA' n '		if (!nested_eptp_ok(cap, eptp)) {' '		if (!nested_eptp_ok(~0ULL, eptp)) {'
mut caso_host_fatale_dimenticato COMPILAZIONE n '	switch (nested_operand_copy(vcpu, VM_PROT_WRITE, &cur, sizeof(cur))) {
	case NOPND_OK:
		break;
	case NOPND_INIETTATO:
		return (0);
	case NOPND_HOST_FATALE:
		return (nested_operand_fatale(vcpu));
	case NOPND_CONTESO:
		return (nested_operand_conteso(vcpu));
	}' '	switch (nested_operand_copy(vcpu, VM_PROT_WRITE, &cur, sizeof(cur))) {
	case NOPND_OK:
		break;
	case NOPND_INIETTATO:
		return (0);
	case NOPND_CONTESO:
		return (nested_operand_conteso(vcpu));
	}'
# --- stadio 10
mut s10_k1_limite_avvolto 'K1' n '			if (first <= desc->limit || last > top)' '			if (first < (uint32_t)(desc->limit + 1) || last > top)'
mut s10_k2_assente 'atteso ESEGUITA_VMFAIL, osservato ESEGUITA' n '	if ((field64 >> 32) != 0 || !nested_field_ok(vcpu, field)) {' '	if (!nested_field_ok(vcpu, field)) {'
mut s10_k2_senza_k3 'atteso ESEGUITA, osservato ESEGUITA_VMFAIL' n '	field64 = nested_reg_operando(vcpu, (info >> 28) & 0xf);' '	field64 = vmx_get_guest_reg(vcpu, (info >> 28) & 0xf);'
mut s10_k3_assente 'K3' n '	if (vcpu->nested->exit_paging.cpu_mode != CPU_MODE_64BIT)
		v &= 0xffffffffULL;' ''
mut s10_k6_assente 'atteso ECCEZIONE#6' n '	if ((reason == EXIT_REASON_INVEPT || reason == EXIT_REASON_INVVPID) &&
	    !nested_inv_esposta(vcpu->nested, reason)) {' '	if (0 &&
	    !nested_inv_esposta(vcpu->nested, reason)) {'
mut s10_k6_solo_capacita 'atteso ECCEZIONE#6' n '		return ((ctl2 & PROCBASED2_ENABLE_EPT) != 0 && (cap & (1ULL << 20)) != 0);' '		return ((cap & (1ULL << 20)) != 0);'
mut s10_k6_dopo_la_cpl 'atteso ECCEZIONE#6, osservato ECCEZIONE#13' n '	if ((reason == EXIT_REASON_INVEPT || reason == EXIT_REASON_INVVPID) &&
	    !nested_inv_esposta(vcpu->nested, reason)) {' '	if (vcpu->nested->exit_paging.cpl != 0) {
		vm_inject_gp(vcpu->vcpu);
		return (true);
	}
	if ((reason == EXIT_REASON_INVEPT || reason == EXIT_REASON_INVVPID) &&
	    !nested_inv_esposta(vcpu->nested, reason)) {'
# --- stadio 11 (P3)
mut s11_conteso_come_iniettato 'osservato SALTO_SILENZIOSO(contesa' n '			if (error == 0 && !fault && conteso)	/* P3 */
				return (NOPND_CONTESO);' '			if (error == 0 && !fault && conteso)	/* P3 */
				return (NOPND_INIETTATO);'
mut s11_conteso_senza_teardown 'RISORSE' n '		if (error == 0 && !fault && conteso) {	/* P3: nulla copiato */
			vm_copy_teardown(ci, nitems(ci));	/* i pezzi gia'"'"' tenuti */' '		if (error == 0 && !fault && conteso) {	/* P3: nulla copiato */'
mut s11_copia_legacy 'LEGACY_SU_CONTESO' n '		error = vm_copy_setup_budget(vcpu->vcpu, &paging, pz[k].gla,
		    pz[k].len, prot, &ci[2 * k], 2, &fault, &conteso);' '		conteso = false;
		error = vm_copy_setup(vcpu->vcpu, &paging, pz[k].gla,
		    pz[k].len, prot, &ci[2 * k], 2, &fault);'
mut s11_pretraduzione_legacy 'LEGACY_SU_CONTESO' n '			error = vm_gla2gpa_budget(vcpu->vcpu, &paging, pga, prot,
			    &gpa, &fault, &conteso);' '			conteso = false;
			error = vm_gla2gpa(vcpu->vcpu, &paging, pga, prot,
			    &gpa, &fault);'
mut s11_senza_segnale 'GIRO_ILLIMITATO' n '	vm_restart_instruction(vcpu->vcpu);
	vm_segnala_conteso(vcpu->vcpu);' '	vm_restart_instruction(vcpu->vcpu);'
mut s11_senza_ripartenza 'osservato SALTO_SILENZIOSO(contesa' n '	vm_restart_instruction(vcpu->vcpu);
	vm_segnala_conteso(vcpu->vcpu);' '	vm_segnala_conteso(vcpu->vcpu);'
mut s11_un_gestore_ignora 'osservato SALTO_SILENZIOSO(contesa' n '	case NOPND_CONTESO:
		return (nested_operand_conteso(vcpu));' '	case NOPND_CONTESO:
		return (0);'
mut s11_gestore_dimenticato COMPILAZIONE n '	case NOPND_CONTESO:
		return (nested_operand_conteso(vcpu));' ''
mut s11_vm_run_non_converte 'GIRO_ILLIMITATO' v '		vme->exitcode = VM_EXITCODE_BOGUS;
		vme->inst_length = 0;
	} else
		conteso = false;' '		(void)0;
	} else
		conteso = false;'
mut s11_flag_non_spento 'FLAG_RESIDUO' v '	vcpu->gla2gpa_conteso = false;
	if (conteso' '	if (conteso'
# sanitizer (indirizzi e comportamento indefinito) sullo stadio finale: stesso esito, nessun rapporto
mkdir -p "$O/asan"; cp "$B/stub.h" "$B/stub-nested.h" "$B/banco.c" "$O/asan/"; cp "$O/fn-$FINALE.inc" "$O/asan/funzioni.inc"
if $CC -g -fsanitize=address,undefined -fno-omit-frame-pointer -I"$O/asan" -o "$O/asan/banco" "$O/asan/banco.c" > "$O/asan/cc.txt" 2>&1; then
	ASAN_OPTIONS=detect_leaks=0 "$O/asan/banco" asan > "$O/asan/esito.txt" 2>&1
	if grep -q 'AddressSanitizer\|runtime error' "$O/asan/esito.txt"; then echo "  ERRATO  sanitizer:"; grep -m5 'AddressSanitizer\|runtime error' "$O/asan/esito.txt"; nf=$((nf+1))
	elif [ "$(tail -1 $O/asan/esito.txt | sed 's/^[^:]*://')" != "$(tail -1 $O/$FINALE/esito.txt | sed 's/^[^:]*://')" ]; then echo "  ERRATO  sanitizer: esito diverso"; nf=$((nf+1))
	else echo "  ok      sanitizer address+undefined: nessun rapporto, stesso esito ($(tail -1 $O/asan/esito.txt | sed 's/^[^:]*: //'))"; fi
else echo "  ERRATO  sanitizer: compilazione fallita"; head -5 "$O/asan/cc.txt"; nf=$((nf+1)); fi


echo "banco-opnd-s11: errori $nf"
[ $nf = 0 ]
