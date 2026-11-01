#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option aggsize=16m
#pragma D option switchrate=10hz
#pragma D option dynvarsize=32m

/*
 * Chi svuota lo shadow EPT durante l'avvio di Windows (Claude 18/10/2026).
 * Righe al secondo: azzeramenti per chiamante, cambi di EPTP12 in
 * vmx_vept_prepare (vecchio -> nuovo), fault dello shadow per vCPU.
 * Offset: vmx_vcpu.nested +696, vcpuid +36 di struct vcpu (vmx_vcpu.vcpu +0?
 * non serve: si usa il puntatore nested come chiave), vept_eptp12 +17728.
 */
fbt:vmm-restore:vmx_vept_invept:entry
{
	@inv[stack(3)] = count();
	@ntot = count();
}

fbt:vmm-restore:vmx_vept_prepare:entry
{
	self->n = *(uintptr_t *)(arg0 + 696);
	self->old = *(uint64_t *)(self->n + 17728);
}

fbt:vmm-restore:vmx_vept_prepare:return
/self->n/
{
	this->new = *(uint64_t *)(self->n + 17728);
	@chg[(long)self->n, (long)self->old, (long)this->new] = sum(self->old != this->new);
	self->n = 0;
}

fbt:vmm-restore:vmx_vept_fault:entry
{
	@flt[(long)*(uintptr_t *)(arg0 + 696)] = count();
}

tick-1s
{
	printf("=== %Y\n", walltimestamp);
	printa("invept tot %@d\n", @ntot);
	printa("azzeramento da:%k %@d\n", @inv);
	printa("eptp12 n=%#lx %#lx -> %#lx: %@d\n", @chg);
	printa("fault n=%#lx: %@d\n", @flt);
	trunc(@ntot); trunc(@inv); trunc(@chg); trunc(@flt);
}
