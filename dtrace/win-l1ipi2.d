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


/* ---------- COERENZA PPR <-> ISR, letta su :return (DOPO il ricalcolo) ----------
 * Errore da non ripetere: su :entry il PPR e' il valore VECCHIO, che la funzione
 * sta per aggiornare -- una discordanza li' e' NORMALE e non prova nulla. Il
 * puntatore al vlapic si conserva dall'entry perche' su fbt:return arg0 non e'
 * piu' il parametro.
 * Invariante (TPR e' sempre 0 in questo guest): nessun bit ISR => PPR = 0.
 * NB: vlapic_read del PPR (vlapic.c:1448) NON ricalcola: il guest puo' leggere
 * un valore stantio. Qui si misura quanto il valore memorizzato e' corretto.
 */
fbt:vmm-restore:vlapic_update_ppr:entry /go/ { self->uvl = arg0; }
fbt:vmm-restore:vlapic_update_ppr:return /self->uvl/
{
	this->cpu = *(int *)(self->uvl + 16);
	this->pg = *(uintptr_t *)(self->uvl + 24);
	this->w7 = *(uint32_t *)(this->pg + 0x170);
	this->w6 = *(uint32_t *)(this->pg + 0x160);
	this->w5 = *(uint32_t *)(this->pg + 0x150);
	this->w4 = *(uint32_t *)(this->pg + 0x140);
	this->w3 = *(uint32_t *)(this->pg + 0x130);
	this->w2 = *(uint32_t *)(this->pg + 0x120);
	this->w1 = *(uint32_t *)(this->pg + 0x110);
	this->w0 = *(uint32_t *)(this->pg + 0x100);
	this->top = this->w7 ? 7 : this->w6 ? 6 : this->w5 ? 5 : this->w4 ? 4 :
	    this->w3 ? 3 : this->w2 ? 2 : this->w1 ? 1 : this->w0 ? 0 : -1;
	this->ppr = *(uint32_t *)(this->pg + 0xa0);
	@coer[this->cpu, this->ppr != 0 ? 1 : 0, this->top >= 0 ? 1 : 0] = count();
	@pprisr[this->cpu, this->ppr >> 4, this->top] = count();
	@tprv[this->cpu, *(uint32_t *)(this->pg + 0x80)] = count();
	self->uvl = 0;
}

/* ---------- accettazione e EOI: la vita del vettore in servizio ---------- */
fbt:vmm-restore:vlapic_intr_accepted:entry /go/
{
	this->cpu = *(int *)(arg0 + 16);
	this->pg = *(uintptr_t *)(arg0 + 24);
	@acc[this->cpu, (int)arg1] = count();
	if ((int)arg1 == 0xef || (int)arg1 == 0xb8) {
		printf("%10d ACC    LP%d v=%#x (prima) ppr=%#x isr5=%#x isr7=%#x\n",
		    (timestamp - t0) / 1000, this->cpu, (int)arg1,
		    *(uint32_t *)(this->pg + 0xa0),
		    *(uint32_t *)(this->pg + 0x150),
		    *(uint32_t *)(this->pg + 0x170));
	}
}
fbt:vmm-restore:vlapic_process_eoi:entry /go/
{
	this->pg = *(uintptr_t *)(arg0 + 24);
	self->ecpu = *(int *)(arg0 + 16) + 1; self->epg = this->pg;
	self->eppr = *(uint32_t *)(this->pg + 0xa0);
	self->e5 = *(uint32_t *)(this->pg + 0x150);
	self->e7 = *(uint32_t *)(this->pg + 0x170);
	@eoi[self->ecpu - 1] = count();
}
fbt:vmm-restore:vlapic_process_eoi:return /self->ecpu && (self->e5 || self->e7)/
{
	printf("%10d EOI    LP%d prima ppr=%#x isr5=%#x isr7=%#x | dopo ppr=%#x isr5=%#x isr7=%#x\n",
	    (timestamp - t0) / 1000, self->ecpu - 1, self->eppr, self->e5, self->e7,
	    *(uint32_t *)(self->epg + 0xa0), *(uint32_t *)(self->epg + 0x150),
	    *(uint32_t *)(self->epg + 0x170));
}
fbt:vmm-restore:vlapic_process_eoi:return /self->ecpu/ { self->ecpu = 0; }

/* chi genera i vettori che non vengono da un ICR */
fbt:vmm-restore:vlapic_fire_lvt:entry /go/
{ @lvt[*(int *)(arg0 + 16), (int)arg1] = count(); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/
{ @callout[*(int *)(arg0 + 16)] = count(); }
fbt:vmm-restore:vioapic_send_intr:entry /go/ { @ioapic[(int)arg1] = count(); }
fbt:vmm-restore:lapic_intr_msi:entry /go/    { @msi[arg2 & 0xff] = count(); }

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
	printa("  COERENZA LP%d ppr_non_nullo=%d isr_impostato=%d = %@d\n", @coer);
	printa("  ppr/isr  LP%d classe_ppr=%#x top_isr=%d = %@d\n", @pprisr);
	printa("  TPR      LP%d = %#x : %@d\n", @tprv);
	printa("  LVT      LP%d indice %d = %@d\n", @lvt);
	printa("  callout  LP%d = %@d\n", @callout);
	printa("  IOAPIC   vett %#x = %@d\n", @ioapic);
	printa("  MSI      vett %#x = %@d\n", @msi);
	printa("  accepted LP%d vett %#x = %@d\n", @acc);
	printa("  EOI      LP%d = %@d\n", @eoi);
}
