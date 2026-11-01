#pragma D option quiet
#pragma D option switchrate=10hz
/*
 * ept_l0_repro.d -- Claude 26/10/2026, v3 (parere #71 §4-5). SOLA LETTURA.
 * Una traccia per OGNI corsa. Marcatori: "== TRACCIA PRONTA ==" (sonde
 * agganciate, si puo' avviare il programma) e "== TRACCIA CHIUSA ==" (END).
 *
 * Il CTF del modulo ha solo forward declaration di struct vmx_vcpu: si usano
 * offset ricavati dal BINARIO INSTALLATO (vmm-restore.ko 149fa57e):
 *   vcpu->vmx        = +0x00  (vmx_run: mov (%rdi),%rax)
 *   vmx->eptp        = +0x10  (vmx_pmap_activate: mov 0x10(%rcx),%rax)
 *   vmx->eptgen[cpu] = +0x18 + 8*cpu  (mov %rax,0x18(%rcx,%rbx,8))
 * Fra la scrittura di eptgen[cpu] (1e877) e l'invept (1e897) non ci sono salti
 * e un invept fallito va in panic: eptgen[cpu] AGGIORNATO => INVEPT(SINGLE, eptp)
 * ESEGUITO su quella CPU. Lo si vede confrontando ENTRY (prima) ed EXIT (dopo).
 *
 * Identita': execname "ept_l0_repro" + puntatore vmx (unico per istanza VM).
 * Reason 48 su RAM -> PAGING     = SDT vmm:vmx:exit:nestedfault (vmx.c:3461-3466)
 * Reason 48 su non-RAM -> INST_EMUL = SDT vmm:vmx:exit:mmiofault (vmx.c:3469-3471)
 */

BEGIN
{
	printf("== TRACCIA PRONTA ==\n");
}

fbt:vmm-restore:vmx_run:entry
/ execname == "ept_l0_repro" /
{
	this->vmx = *(uintptr_t *)arg0;
	this->pm = (pmap_t)arg2;
	this->gcpu = *(long *)(this->vmx + 0x18 + cpu * 8);
	printf("%d ENTRY vmx=%p cpu%d eptp=%#lx pm_pmltop=%p pm_eptgen=%d vmx_eptgen[cpu]=%d%s\n",
	    timestamp, (void *)this->vmx, cpu,
	    *(uint64_t *)(this->vmx + 0x10), this->pm->pm_pmltop,
	    this->pm->pm_eptgen, this->gcpu,
	    this->pm->pm_eptgen != this->gcpu ? "  -> INVEPT DOVUTO" : "");
}

vmm:vmx:exit:return
/ execname == "ept_l0_repro" /
{
	this->vmx = (uintptr_t)arg0;
	printf("%d EXIT  vmx=%p cpu%d vmx_eptgen[cpu]=%d handled=%d\n",
	    timestamp, (void *)this->vmx, cpu,
	    *(long *)(this->vmx + 0x18 + cpu * 8), (int)arg3);
}

vmm:vmx:exit:nestedfault
/ execname == "ept_l0_repro" && (arg3 & ~0xfffUL) == 0x20000 /
{
	printf("%d REASON48 -> PAGING    vmx=%p gpa=%#lx qual=%#lx cpu%d\n",
	    timestamp, (void *)arg0, arg3, arg4, cpu);
}

vmm:vmx:exit:mmiofault
/ execname == "ept_l0_repro" && (arg3 & ~0xfffUL) == 0x20000 /
{
	printf("%d REASON48 -> INST_EMUL vmx=%p gpa=%#lx cpu%d\n",
	    timestamp, (void *)arg0, arg3, cpu);
}

fbt:kernel:vm_fault:entry
/ execname == "ept_l0_repro" && (arg1 & ~0xfffUL) == 0x20000 /
{
	printf("%d vm_fault gpa=%#lx cpu%d\n", timestamp, arg1, cpu);
}

END
{
	printf("== TRACCIA CHIUSA ==\n");
}
