#pragma D option quiet
#pragma D option dynvarsize=16m
#pragma D option bufsize=8m
/*
 * attribuzione-pf.d -- Claude 04/11/2026 (parere Opus 003, misura 1): ogni via con cui L0 puo' far nascere un #PF.
 * struct vm_guest_paging (vmm.h, 3b7654d74b42): cr3 @0 (u64), cpl @8, cpu_mode @12, paging_mode @16 (int).
 * _vm_gla2gpa(vcpu, paging, gla, prot, gpa*, guest_fault*, check_only, conteso*)
 * vmm_fetch_instruction(vcpu, paging, rip, len, vie*, faultptr*)
 */
fbt:vmm-restore:vm_inject_pf:entry
{
	printf("%Y vm_inject_pf err=%#x cr2=%#lx vcpu=%p\n", walltimestamp, arg1, arg2, arg0);
	stack(16);
}
fbt:vmm-restore:vm_inject_fault:entry
/arg1 == 14/
{
	printf("%Y vm_inject_fault #PF errvalid=%d err=%#x vcpu=%p\n", walltimestamp, arg2, arg3, arg0);
	stack(16);
}
fbt:vmm-restore:_vm_gla2gpa:entry
{
	self->gf = arg5; self->gla = arg2; self->prot = arg3; self->pg = arg1; self->co = arg6;
	@n["_vm_gla2gpa"] = count();
}
fbt:vmm-restore:_vm_gla2gpa:return
/self->gf && (arg1 != 0 || *(int *)self->gf != 0)/
{
	@gf[arg1, *(int *)self->gf, self->prot, self->co, *(int *)(self->pg + 8), *(int *)(self->pg + 16)] = count();
	@ultimo_gla[arg1, *(int *)self->gf, self->prot] = max(self->gla);
}
fbt:vmm-restore:_vm_gla2gpa:return { self->gf = 0; }
fbt:vmm-restore:vmm_fetch_instruction:entry
{
	self->fp = arg5; self->rip = arg2; self->fpg = arg1;
	@n["vmm_fetch_instruction"] = count();
}
fbt:vmm-restore:vmm_fetch_instruction:return
/self->fp && (arg1 != 0 || *(int *)self->fp != 0)/
{
	@ff[arg1, *(int *)self->fp, *(int *)(self->fpg + 8), *(int *)(self->fpg + 16)] = count();
	@n["fetch con fault/errore"] = count();
	/* le prime 40 per esteso */
	this->k = ++nff;
}
fbt:vmm-restore:vmm_fetch_instruction:return
/self->fp && (arg1 != 0 || *(int *)self->fp != 0) && nff <= 40/
{
	printf("%Y fetch rc=%d fault=%d rip=%#lx cr3=%#lx cpl=%d pmode=%d\n", walltimestamp, arg1, *(int *)self->fp,
	    self->rip, *(uint64_t *)self->fpg, *(int *)(self->fpg + 8), *(int *)(self->fpg + 16));
	stack(12);
}
fbt:vmm-restore:vmm_fetch_instruction:return { self->fp = 0; }
tick-60s
{
	printf("%Y vivo\n", walltimestamp);
	printa("  %-26s %@d\n", @n); clear(@n);
	printf("  gla2gpa con fault/errore [rc fault prot check_only cpl pmode] -> conteggio:\n");
	printa("    %d %d %#x %d %d %d -> %@d\n", @gf);
	printf("  fetch con fault/errore [rc fault cpl pmode] -> conteggio:\n");
	printa("    %d %d %d %d -> %@d\n", @ff);
}
tick-4800s
{
	printf("ultimo gla per tipo [rc fault prot]:\n");
	printa("    %d %d %#x -> %@#lx\n", @ultimo_gla);
	exit(0);
}
