#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Astra Fase 1: CHI scrive ICR_timer=0 (disarmo)? L1 o L2?
 * Ipotesi: una scrittura APIC di L2 (Windows root) applicata per errore al
 * vlapic di L1 disarma il clock di Hyper-V. Al momento della scrittura del
 * timer-ICR, il thread sta elaborando l'uscita corrente: ne catturo motivo,
 * rip e lo stato nested (in_l2) impostati in exit:entry, piu' lo stack kernel.
 * Offset: vmx_vcpu.nested +696, nested.in_l2 +1; vmexit +20 reason, +8 rip.
 * vlapic.vcpuid +16, apic_page +24; icr_timer +896, lvt_timer +800, dcr +992.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

vmm:vmx:exit:entry /go/
{
	self->reason = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	self->rip = *(uint64_t *)((uintptr_t)arg2 + 8);
	this->n = *(uintptr_t *)(arg0 + 696);
	self->l2 = this->n ? *(uint8_t *)(this->n + 1) : 0;
	self->seen = 1;
}

fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	this->icr = *(uint32_t *)(this->p + 896);
	this->lvt = *(uint32_t *)(this->p + 800);
	this->dcr = *(uint32_t *)(this->p + 992);
	printf("%10d cpu%d ICR-SET=%u lvt=%#x dcr=%#x | in_l2=%d exit=%d rip=%#lx\n",
	    (timestamp - t0)/1000, *(int *)(arg0 + 16), this->icr, this->lvt, this->dcr,
	    self->seen ? self->l2 : -1, self->seen ? self->reason : -1,
	    self->seen ? self->rip : 0);
}

/* dettaglio + stack SOLO sui disarmi (icr=0), per non inondare */
fbt:vmm-restore:vlapic_icrtmr_write_handler:entry
/go && *(uint32_t *)(*(uintptr_t *)(arg0 + 24) + 896) == 0/
{
	printf("    ^DISARMO cpu%d in_l2=%d exit=%d stack:\n", *(int *)(arg0 + 16),
	    self->seen ? self->l2 : -1, self->seen ? self->reason : -1);
	stack(8);
}

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
