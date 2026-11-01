#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option aggsize=16m
#pragma D option switchrate=10hz

/*
 * Come Hyper-V (L1) arma il tempo su ogni LP (Claude 18/10/2026). Sulla CPU1
 * il timer APIC non viene MAI caricato (nessuna scrittura ICR non nulla), ma
 * allo stallo l'LVT vale 0xef: TSC-deadline (0x6e0, ignorato da bhyve -w)?
 * Al secondo, per CPU e livello (L1/L2): WRMSR per numero (con l'ultimo
 * valore), scritture LVT del timer, scritture ICR del timer.
 * Offset: vmx_vcpu.vcpuid +704, nested +696, in_l2 +1; vlapic.vcpuid +16,
 * apic_page +24; LAPIC lvt_timer +800, icr_timer +896.
 */
fbt:vmm-restore:vmx_wrmsr:entry
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->l2 = this->n ? *(uint8_t *)(this->n + 1) : 0;
	@w[*(int *)(arg0 + 704), this->l2, (long)arg1] = count();
	@wv[*(int *)(arg0 + 704), this->l2, (long)arg1] = max((long)arg2);
}

fbt:vmm-restore:lapic_wrmsr:entry
{
	@x[*(int *)(arg0 + 36), (long)arg1] = count();
	@xv[*(int *)(arg0 + 36), (long)arg1] = max((long)arg2);
}

fbt:vmm-restore:vlapic_lvt_write_handler:entry
{
	self->vl = arg0;
	self->off = arg1;
}

fbt:vmm-restore:vlapic_lvt_write_handler:return
/self->vl && self->off == 0x320/
{
	@lvt[*(int *)(self->vl + 16),
	    *(uint32_t *)(*(uintptr_t *)(self->vl + 24) + 800)] = count();
}

fbt:vmm-restore:vlapic_lvt_write_handler:return
{
	self->vl = 0;
}

fbt:vmm-restore:vlapic_icrtmr_write_handler:entry
{
	@icr[*(int *)(arg0 + 16),
	    *(uint32_t *)(*(uintptr_t *)(arg0 + 24) + 896) != 0] = count();
}

tick-1s
{
	printf("=== %Y\n", walltimestamp);
	printa("wrmsr cpu%d L%d msr %#lx: %@d volte, max %@#lx\n", @w, @wv);
	printa("x2apic cpu%d msr %#lx: %@d volte, max %@#lx\n", @x, @xv);
	printa("lvt-timer cpu%d = %#x: %@d\n", @lvt);
	printa("icr-timer cpu%d armato=%d: %@d\n", @icr);
	trunc(@w); trunc(@wv); trunc(@x); trunc(@xv); trunc(@lvt); trunc(@icr);
}
