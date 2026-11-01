#pragma D option quiet
#pragma D option switchrate=4hz
/*
 * Claude 20/10/2026 -- da dove viene il #UD che uccide smss.exe (ExitStatus
 * 0xC000001D, letto dalla copia dell'EPROCESS nel dump triage del pagefile).
 * Con hw.vmm.vmx.diag_vec=6: ogni ingresso hardware in L2 che inietta #UD.
 *   FONTE c12 = cosa chiedeva il VMCS12 (Hyper-V) all'ultima compose;
 *   se c12 non e' #UD, l'iniezione e' di L0.
 * In piu' vm_inject_exception con vettore 6 (L0 che decide un #UD), con lo
 * stack del kernel per vedere il percorso.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

vmm:vmx:nested:compose /go/
{
	self->c12 = (arg1 & 0x80000000) ? (arg1 & 0xffffffff) : 0;
	self->c12t = timestamp;
}
vmm:vmx:nested:compose /go && (arg1 & 0x800000ff) == 0x80000006/
{
	printf("%10d COMPOSE VP%d: Hyper-V chiede #UD in L2, ei=%#x\n", (timestamp - t0) / 1000,
	    *(int *)(arg0 + 704), (int)(arg1 & 0xffffffff));
}
vmm:vmx:nested:diag_entry { self->ei = arg1 & 0xffffffff; self->rip = arg2; self->rfl = arg5; self->us = (timestamp - t0) / 1000; }
vmm:vmx:nested:diag_exit
{
	printf("%10d INJ #UD VP%d ei=%#x rip=%#lx rfl=%#lx FONTE c12=%#x (eta %d us) -> usc reason=%d idtvec=%#x rip=%#lx\n",
	    self->us, (int)arg0, (int)self->ei, self->rip, self->rfl, (int)self->c12,
	    self->c12t ? (timestamp - self->c12t) / 1000 : -1,
	    (int)(arg1 & 0xffff), (int)(arg1 >> 32), arg3);
}
fbt:vmm-restore:vm_inject_exception:entry /go && arg1 == 6/
{
	printf("%10d L0 vm_inject_exception(#UD)\n", (timestamp - t0) / 1000);
	stack(12);
}
vmm:vmx:nested:diag_exit { @tick_ult = max((timestamp - t0) / 1000); }
tick-5s /go/ { printa("  ultimo #UD catturato: %@d us\n", @tick_ult); }
