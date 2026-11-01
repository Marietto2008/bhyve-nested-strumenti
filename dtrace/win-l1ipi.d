#pragma D option quiet
#pragma D option bufsize=128m
#pragma D option aggsize=16m
#pragma D option switchrate=2hz
#pragma D option dynvarsize=16m
/*
 * Claude 19/10/2026 -- Astra #14 STADIO A: la catena completa degli IPI fra i
 * processori logici dell'L1 (Hyper-V), piu' le iniezioni di 0xd1 in L2, nello
 * STESSO tracciatore e con lo STESSO orologio, per confrontare i cicli SANI con
 * l'unico ciclo che diverge.
 *
 * NB (correzione di Astra): l'L1 puo' usare xAPIC (ICR MMIO 0x300/0x310) e non
 * x2APIC. Non si traccia il MSR 0x830: si traccia l'UNICO gestore che copre
 * entrambi i casi, vlapic_icrlo_write_handler, e la modalita' viene dal
 * parametro x2apic_dest di vlapic_calcdest. NESSUN filtro per vettore.
 *
 * Offset verificati con offsetof reale:
 *   struct vlapic:  vcpuid +16, apic_page +24
 *   struct LAPIC:   tpr 0x80, isr0 0x100, svr 0xf0, ppr 0xa0, irr0 0x200,
 *                   icr_lo 0x300, icr_hi 0x310  (registri da 16 byte)
 *   struct vmx_vcpu: vcpuid +704
 * lapic_intr_edge e' inline: il gradino di consegna si vede su lapic_set_intr
 * e vlapic_set_intr_ready.
 */
int go; int64_t t0;
int l2[int];			/* in_l2 per vcpuid dell'L1 */

vmm:vmx:nested:enter_l2 /!go/
{
	go = 1; t0 = timestamp;
	printf("T0 walltimestamp=%d\n", walltimestamp);
}

/* chi sta dentro L2 in questo momento */
vmm:vmx:nested:compose /go/            { l2[*(int *)(arg0 + 704)] = 1; }
fbt:vmm-restore:nested_l2_exit:entry /go/ { l2[*(int *)(arg0 + 704)] = 0; }

/* ---------- il PRODUTTORE: un LP dell'L1 scrive l'ICR ---------- */
fbt:vmm-restore:vlapic_icrlo_write_handler:entry /go/
{
	this->vl = arg0;
	this->cpu = *(int *)(this->vl + 16);
	this->pg = *(uintptr_t *)(this->vl + 24);
	this->lo = *(uint32_t *)(this->pg + 0x300);
	this->hi = *(uint32_t *)(this->pg + 0x310);
	self->icr = 1; self->icrlo = this->lo;
	printf("%10d ICR    LP%d lo=%#x hi=%#x vett=%#x mode=%d destlog=%d short=%d in_l2=%d\n",
	    (timestamp - t0) / 1000, this->cpu, this->lo, this->hi,
	    this->lo & 0xff, (this->lo >> 8) & 7, (this->lo >> 11) & 1,
	    (this->lo >> 18) & 3, l2[this->cpu]);
	@icr[this->cpu, this->lo & 0xff, (this->lo >> 8) & 7] = count();
	@icr_ult[this->cpu, this->lo & 0xff] = max((timestamp - t0) / 1000);
}

/* la destinazione calcolata, e la MODALITA' (x2apic o xapic) */
fbt:vmm-restore:vlapic_calcdest:entry /go && self->icr/
{
	printf("%10d   dest dest=%#x phys=%d x2apic=%d\n", (timestamp - t0) / 1000,
	    (int)arg2, (int)arg3, (int)arg5);
	@modo[(int)arg5] = count();
}

/* ---------- la CONSEGNA: IRR del destinatario ---------- */
fbt:vmm-restore:vlapic_set_intr_ready:entry /go/
{
	this->vl = arg0;
	this->tgt = *(int *)(this->vl + 16);
	this->pg = *(uintptr_t *)(this->vl + 24);
	this->v = (int)arg1;
	this->off = (this->v / 32) * 16;	/* registro IRR/ISR da 16 byte */
	self->tgt = this->tgt + 1; self->v = this->v;
	printf("%10d  ->IRR LP%d vett=%#x svr=%#x tpr=%#x ppr=%#x irr=%#x isr=%#x in_l2=%d daICR=%d\n",
	    (timestamp - t0) / 1000, this->tgt, this->v,
	    *(uint32_t *)(this->pg + 0xf0), *(uint32_t *)(this->pg + 0x80),
	    *(uint32_t *)(this->pg + 0xa0),
	    *(uint32_t *)(this->pg + 0x200 + this->off),
	    *(uint32_t *)(this->pg + 0x100 + this->off),
	    l2[this->tgt], self->icr ? 1 : 0);
	@irr[this->tgt, this->v] = count();
	@irr_ult[this->tgt, this->v] = max((timestamp - t0) / 1000);
}

/* il risveglio richiesto */
fbt:vmm-restore:vcpu_notify_lapic:entry /go && self->tgt/
{
	printf("%10d  notify LP%d vett=%#x\n", (timestamp - t0) / 1000,
	    self->tgt - 1, self->v);
	@notify[self->tgt - 1, self->v] = count();
}
fbt:vmm-restore:vlapic_set_intr_ready:return /self->tgt/ { self->tgt = 0; }
fbt:vmm-restore:vlapic_icrlo_write_handler:return /self->icr/ { self->icr = 0; }

/* ---------- la TRANSIZIONE verso L1 mentre L2 e' attivo ---------- */
fbt:vmm-restore:nested_check_events:entry /go/ { self->nce = *(int *)(arg0 + 704) + 1; }
fbt:vmm-restore:nested_check_events:return /self->nce/
{
	if (arg1) {
		printf("%10d  chkev LP%d -> uscita a L1\n", (timestamp - t0) / 1000,
		    self->nce - 1);
		@chkev[self->nce - 1] = count();
	}
	self->nce = 0;
}
fbt:vmm-restore:nested_l1_intercepts_extint:entry /go/ { self->nie = *(int *)(arg0 + 704) + 1; }
fbt:vmm-restore:nested_l1_intercepts_extint:return /self->nie/
{
	@extint[self->nie - 1, (int)arg1] = count();
	self->nie = 0;
}

/* ---------- l'ANCORA: le iniezioni di 0xd1 in L2 (diagnostica ff32386) ---------- */
vmm:vmx:nested:diag_entry
{
	self->mt = arg3 & 0xffffffff; self->exp = arg4;
	self->dus = (timestamp - t0) / 1000; self->dw = walltimestamp;
}
vmm:vmx:nested:diag_exit
{
	printf("%10d TICK   VP%d vtl=%#lx wall=%d mt=%#x exp=%d usc_reason=%d idtvec=%#x\n",
	    self->dus, (int)arg0, arg5, self->dw, (int)self->mt, self->exp,
	    (int)(arg1 & 0xffff), (int)(arg1 >> 32));
	@tick[(int)arg0] = count();
	@tick_ult[(int)arg0] = max(self->dus);
}
vmm:vmx:nested:diag_simp
{
	printf("%10d SIMP   VP%d gpa=%#lx val=%#lx\n",
	    go ? (timestamp - t0) / 1000 : 0, (int)arg0, arg1, arg2);
}

tick-10s /go/
{
	printf("=== %d s  wall=%d\n", (timestamp - t0) / 1000000000, walltimestamp);
	printa("  ICR      LP%d vett %#x mode %d = %@d\n", @icr);
	printa("  ICR ult  LP%d vett %#x = %@d us\n", @icr_ult);
	printa("  modalita x2apic=%d = %@d\n", @modo);
	printa("  IRR      LP%d vett %#x = %@d\n", @irr);
	printa("  IRR ult  LP%d vett %#x = %@d us\n", @irr_ult);
	printa("  notify   LP%d vett %#x = %@d\n", @notify);
	printa("  chkev    LP%d = %@d\n", @chkev);
	printa("  extint   LP%d intercetta=%d = %@d\n", @extint);
	printa("  tick     VP%d = %@d\n", @tick);
	printa("  tick ult VP%d = %@d us\n", @tick_ult);
}
