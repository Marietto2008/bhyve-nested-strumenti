#pragma D option quiet
#pragma D option switchrate=4hz
/*
 * Claude 20/10/2026 -- parere #19: l'EFER del VMCS02 a ogni ingresso in L2.
 * efer(vcpuid, efer12, efer02, l1_efer, entry_ctls12, list_efer)
 *   list_efer bit63 = IA32_EFER presente nella MSR-load list del VMCS12
 * VM_ENTRY_LOAD_EFER = 1<<15 = 0x8000
 * Prima: sysctl hw.vmm.vmx.diag_efer=1
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:nested:efer
{
	this->load = (arg4 >> 15) & 1;		/* VM_ENTRY_LOAD_EFER */
	this->lp = (arg5 >> 63) & 1;		/* lista contiene EFER */
	@per[arg2, this->lp, (int)(arg2 & 1)] = count();   /* efer02, lista?, SCE02 */
	/* stampa i primi di ogni combinazione efer02 */
	@sce02[(int)(arg2 & 1)] = count();
	@sce12[(int)(arg1 & 1)] = count();
	@list[this->lp, (int)(arg5 & 1)] = count();
	@load_ctl[this->load] = count();
	printf("%8d VP%d efer12=%#lx efer02=%#lx(SCE=%d) l1=%#lx LOAD_EFER=%d lista_EFER=%d val=%#lx\n",
	    (timestamp - t0)/1000000, (int)arg0, arg1, arg2, (int)(arg2 & 1),
	    arg3, (int)this->load, (int)this->lp, arg5 & 0x7fffffffffffffff);
}
tick-5s /go/
{
	printf("=== riepilogo ===\n");
	printa("  efer02 SCE=%d : %@d\n", @sce02);
	printa("  efer12 SCE=%d : %@d\n", @sce12);
	printa("  lista EFER presente=%d valSCE=%d : %@d\n", @list);
	printa("  VM_ENTRY_LOAD_EFER=%d : %@d\n", @load_ctl);
	clear(@sce02); clear(@sce12); clear(@list); clear(@load_ctl);
}
