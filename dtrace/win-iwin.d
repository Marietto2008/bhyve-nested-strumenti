#pragma D option quiet
#pragma D option bufsize=128m
#pragma D option aggsize=16m
#pragma D option switchrate=4hz
#pragma D option dynvarsize=16m
/*
 * Claude 19/10/2026 -- dopo Astra #14: Hyper-V riceve il portatore 0xef,
 * lo gestisce, e NON inietta 0xd1. Ipotesi: in quell'istante L2 non e'
 * interrompibile, Hyper-V chiede l'INTERRUPT WINDOW nel VMCS12, e la finestra
 * non arriva. Nessuna modifica al modulo: la sonda compose porta gia' tutto.
 *   nested:compose(vcpu, VMCS12 ENTRY_INTR_INFO, pin, VMCS12 proc,
 *                  RFLAGS<<32 | interruptibility)    -- RFLAGS/intblk sono di L2
 *   PROCBASED_INT_WINDOW_EXITING = bit 2 ; RFLAGS.IF = bit 9
 *   nested_l2_exit: reason 7 = INTR_WINDOW ; reflect = riflessa all'L1
 */
int go; int64_t t0;

vmm:vmx:nested:enter_l2 /!go/
{ go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

vmm:vmx:nested:compose /go && *(int *)(arg0 + 704) == 0/
{
	this->ei = arg1 & 0xffffffff;
	this->iw = (arg3 >> 2) & 1;
	this->rf = arg4 >> 32;
	this->ifl = (this->rf >> 9) & 1;
	this->blk = arg4 & 0xffffffff;
	printf("%10d C ei=%#x iw=%d if=%d blk=%#x\n", (timestamp - t0) / 1000,
	    (int)this->ei, (int)this->iw, (int)this->ifl, (int)this->blk);
	@c[this->iw, this->ifl, this->blk != 0 ? 1 : 0,
	    (this->ei & 0x80000000) ? (int)(this->ei & 0xff) : -1] = count();
}

fbt:vmm-restore:nested_l2_exit:entry /go/
{
	self->cpu = *(int *)(arg0 + 704);
	self->r = *(uint32_t *)(arg1 + 20) & 0xffff;
	self->in = 1; self->refl = 0;
}
vmm:vmx:nested:reflect /self->in/ { self->refl = 1; }
fbt:vmm-restore:nested_l2_exit:return /self->in/
{
	if (self->r == 7) {
		printf("%10d W VP%d INTR_WINDOW %s\n", (timestamp - t0) / 1000,
		    self->cpu, self->refl ? "riflessa" : "L0");
		@w[self->cpu, self->refl] = count();
	}
	self->in = 0;
}

fbt:vmm-restore:vlapic_set_intr_ready:entry /go && (int)arg1 == 0xef/
{
	printf("%10d E 0xef LP%d\n", (timestamp - t0) / 1000, *(int *)(arg0 + 16));
}

vmm:vmx:nested:diag_entry { self->exp = arg4; self->dus = (timestamp - t0) / 1000; }
vmm:vmx:nested:diag_exit
{
	printf("%10d T VP%d exp=%d\n", self->dus, (int)arg0, self->exp);
}

tick-10s /go/
{
	printf("=== %d s\n", (timestamp - t0) / 1000000000);
	printa("  compose VP0 iw=%d if=%d blk=%d vett=%d : %@d\n", @c);
	printa("  INTR_WINDOW VP%d riflessa=%d : %@d\n", @w);
}
