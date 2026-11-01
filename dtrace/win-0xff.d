#pragma D option quiet
#pragma D option bufsize=48m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Astra #5: identificare la SEMANTICA dell'IPI 0xff.
 * 0xff e' solo il campo vettore; conta il delivery mode (icrlo bit 10:8):
 * 0=FIXED, 4=NMI, 5=INIT, 6=SIPI. Catturo l'ICR completo (decode) + il RIP
 * L1 del mittente (rip dell'uscita che emula la scrittura APIC). All'accept
 * su cpu0: PPR e ISR (0xff classe 0xf0 > timer 0xef classe 0xe0: se 0xff
 * resta in ISR puo' bloccare il timer). All'EOI: ISR prima.
 * apic_page = vlapic+24; ICR_LO 0x300, ICR_HI 0x310, PPR 0xA0,
 * ISR6(192-223) 0x160, ISR7(224-255) 0x170, IRR7 0x270. vlapic.vcpuid +16.
 * exit:entry arg2=vmexit (+8 rip).
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

vmm:vmx:exit:entry /go/ { self->rip = *(uint64_t *)((uintptr_t)arg2 + 8); }

fbt:vmm-restore:vlapic_icrlo_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	this->lo = *(uint32_t *)(this->p + 0x300);
	this->hi = *(uint32_t *)(this->p + 0x310);
	this->vec = this->lo & 0xff;
	this->dm = (this->lo >> 8) & 7;
	/* stampo gli IPI del clock e QUALUNQUE delivery-mode non-FIXED */
	if (this->vec == 0xff || this->vec == 0xd2 || this->dm != 0)
		printf("%10d cpu%d ICR vec=%#x dmode=%d short=%d trig=%d dest=%d icrlo=%#x | rip=%#lx\n",
		    (timestamp - t0)/1000, *(int *)(arg0 + 16), this->vec, this->dm,
		    (this->lo >> 18) & 3, (this->lo >> 15) & 1, (this->hi >> 24) & 0xff,
		    this->lo, self->rip);
}

fbt:vmm-restore:vlapic_intr_accepted:entry /go && (arg1 == 0xff || arg1 == 0xd2 || arg1 == 0xef)/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d cpu%d ACCEPT vec=%#x ppr=%#x isr6=%#x isr7=%#x\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 16), (int)arg1, *(uint32_t *)(this->p + 0xA0),
	    *(uint32_t *)(this->p + 0x160), *(uint32_t *)(this->p + 0x170));
}

fbt:vmm-restore:vlapic_process_eoi:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	this->i6 = *(uint32_t *)(this->p + 0x160);
	this->i7 = *(uint32_t *)(this->p + 0x170);
	if (this->i6 || this->i7)
		printf("%10d cpu%d EOI isr6=%#x isr7=%#x ppr=%#x\n", (timestamp - t0)/1000,
		    *(int *)(arg0 + 16), this->i6, this->i7, *(uint32_t *)(this->p + 0xA0));
}

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
