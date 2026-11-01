#pragma D option quiet
#pragma D option bufsize=128m
#pragma D option switchrate=4hz
#pragma D option dynvarsize=16m
/*
 * Claude 19/10/2026 -- una compose con 0x800000d1 senza ingresso hardware:
 * bhyve riporta l'iniezione NON consegnata all'L1 (IDT_VECTORING_INFO del
 * VMCS12) quando fa un'uscita sintetica invece di entrare in L2?
 * In nested_reflect_to_l1 (vmx_nested.c:1648-1689), con synth:
 *   have (evento pendente di L0) ha PRECEDENZA su ent (iniezione composta):
 *   se ci sono entrambi, ent viene azzerato e NON riportato.
 * Sonde (nessuna modifica al modulo):
 *   compose(vcpu, VMCS12 ENTRY_INTR_INFO, ...)    -- cio' che l'L1 chiede
 *   diag_entry/diag_exit                            -- l'ingresso hardware con 0xd1
 *   nested_check_events:return arg1                 -- 1 = uscita sintetica EXT_INTR
 *   synth_exit(vcpu, idt)                           -- IDT_VECTORING riportato, se valido
 *   nested_reflect_to_l1:entry                      -- ogni riflessione
 */
int go; int64_t t0;

vmm:vmx:nested:enter_l2 /!go/
{ go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

vmm:vmx:nested:compose /go && *(int *)(arg0 + 704) == 0 && (arg1 & 0x80000000)/
{
	printf("%10d C ei=%#x\n", (timestamp - t0) / 1000, (int)(arg1 & 0xffffffff));
}
vmm:vmx:nested:diag_entry { self->dus = (timestamp - t0) / 1000; }
vmm:vmx:nested:diag_exit /(int)arg0 == 0/
{
	printf("%10d T reason=%d idtvec=%#x\n", self->dus, (int)(arg1 & 0xffff),
	    (int)(arg1 >> 32));
}
fbt:vmm-restore:nested_check_events:entry /go/ { self->nce = *(int *)(arg0 + 704) + 1; }
fbt:vmm-restore:nested_check_events:return /self->nce == 1/
{
	if (arg1) printf("%10d X chkev->uscita sintetica EXT_INTR\n", (timestamp - t0) / 1000);
	self->nce = 0;
}
fbt:vmm-restore:nested_check_events:return /self->nce/ { self->nce = 0; }
vmm:vmx:nested:synth_exit /go && *(int *)(arg0 + 704) == 0/
{
	printf("%10d S synth_exit idt=%#x\n", (timestamp - t0) / 1000, (int)arg1);
	@se[(int)arg1] = count();
}
vmm:vmx:nested:chkev /go && *(int *)(arg0 + 704) == 0 && arg2/
{
	printf("%10d K pend=%d vec=%#x pin12=%#lx\n", (timestamp - t0) / 1000,
	    (int)arg2, (int)arg3, arg1);
}
tick-10s /go/ { printa("  synth_exit idt=%#x : %@d\n", @se); }
