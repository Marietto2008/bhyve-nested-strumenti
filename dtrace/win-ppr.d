#pragma D option quiet
#pragma D option bufsize=96m
#pragma D option aggsize=16m
#pragma D option switchrate=2hz
#pragma D option dynvarsize=16m
/*
 * Claude 19/10/2026 -- Astra #14, seguito: lo STATO che Hyper-V legge quando
 * decide se notificare VP0.
 *
 * REPERTO da cui parte: su 949 consegne del vettore portante 0xef al LAPIC di
 * LP0, 948 avvengono con PPR = 0; l'UNICA con PPR = 0xb0 (vettore 0xb8 in
 * servizio) e' esattamente il ciclo in cui Hyper-V deposita il messaggio SynIC
 * e NON chiede l'interrupt.
 *
 * DOMANDA: quel PPR e' architetturalmente corretto, o bhyve lo presenta
 * sbagliato? vlapic_update_ppr calcola il PPR da isrvec_stk[isrvec_stk_top],
 * NON dai bit ISR della pagina APIC: se i due divergono, il PPR e' falso.
 *
 * INVARIANTE CONTROLLATO (TPR e' sempre 0 in questo guest):
 *   nessun bit ISR impostato  =>  PPR deve essere 0.
 * Un solo conteggio in (ppr!=0, nessun ISR) e' un difetto di bhyve.
 *
 * Offset verificati: struct vlapic vcpuid +16, apic_page +24;
 * struct LAPIC tpr 0x80, isr0..7 a 0x100 + k*16, ppr 0xa0, irr0 0x200.
 */
int go; int64_t t0;
int l2[int];

vmm:vmx:nested:enter_l2 /!go/
{ go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

vmm:vmx:nested:compose /go/               { l2[*(int *)(arg0 + 704)] = 1; }
fbt:vmm-restore:nested_l2_exit:entry /go/ { l2[*(int *)(arg0 + 704)] = 0; }

/* ---- coerenza PPR <-> ISR, su OGNI ricalcolo (solo aggregata) ---- */
fbt:vmm-restore:vlapic_update_ppr:entry /go/
{
	this->vl = arg0;
	this->cpu = *(int *)(this->vl + 16);
	this->pg = *(uintptr_t *)(this->vl + 24);
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
	this->tpr = *(uint32_t *)(this->pg + 0x80);
	@coer[this->cpu, this->ppr != 0 ? 1 : 0, this->top >= 0 ? 1 : 0] = count();
	@pprclass[this->cpu, this->ppr >> 4, this->top] = count();
	@tprv[this->cpu, this->tpr] = count();
}

/* ---- la PROVENIENZA dei vettori: chi genera 0xef e 0xb8 ---- */
fbt:vmm-restore:vlapic_fire_lvt:entry /go/
{
	@lvt[*(int *)(arg0 + 16), (int)arg1] = count();
	@lvt_ult[*(int *)(arg0 + 16), (int)arg1] = max((timestamp - t0) / 1000);
}
fbt:vmm-restore:vioapic_send_intr:entry /go/ { @ioapic[(int)arg1] = count(); }
fbt:vmm-restore:lapic_intr_msi:entry /go/    { @msi[arg2 & 0xff] = count(); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/
{ @callout[*(int *)(arg0 + 16)] = count(); }

/* ---- dettaglio sui due vettori che contano ---- */
fbt:vmm-restore:vlapic_set_intr_ready:entry /go && ((int)arg1 == 0xef || (int)arg1 == 0xb8)/
{
	this->vl = arg0; this->cpu = *(int *)(this->vl + 16);
	this->pg = *(uintptr_t *)(this->vl + 24);
	this->off = ((int)arg1 / 32) * 16;
	printf("%10d IRR  LP%d v=%#x ppr=%#x tpr=%#x isr=[%#x %#x %#x %#x %#x %#x %#x %#x] irr_suo=%#x in_l2=%d\n",
	    (timestamp - t0) / 1000, this->cpu, (int)arg1,
	    *(uint32_t *)(this->pg + 0xa0), *(uint32_t *)(this->pg + 0x80),
	    *(uint32_t *)(this->pg + 0x100), *(uint32_t *)(this->pg + 0x110),
	    *(uint32_t *)(this->pg + 0x120), *(uint32_t *)(this->pg + 0x130),
	    *(uint32_t *)(this->pg + 0x140), *(uint32_t *)(this->pg + 0x150),
	    *(uint32_t *)(this->pg + 0x160), *(uint32_t *)(this->pg + 0x170),
	    *(uint32_t *)(this->pg + 0x200 + this->off), l2[this->cpu]);
}

fbt:vmm-restore:vlapic_intr_accepted:entry /go/
{
	this->vl = arg0; this->cpu = *(int *)(this->vl + 16);
	this->pg = *(uintptr_t *)(this->vl + 24);
	@acc[this->cpu, (int)arg1] = count();
	/* :return non esiste (chiamata in coda): lo stato e' quello PRIMA
	 * dell'accettazione, che e' proprio quello su cui si decide */
	if ((int)arg1 == 0xef || (int)arg1 == 0xb8) {
		printf("%10d ACC  LP%d v=%#x (prima) ppr=%#x isr5=%#x isr7=%#x irr5=%#x irr7=%#x\n",
		    (timestamp - t0) / 1000, this->cpu, (int)arg1,
		    *(uint32_t *)(this->pg + 0xa0),
		    *(uint32_t *)(this->pg + 0x150),
		    *(uint32_t *)(this->pg + 0x170),
		    *(uint32_t *)(this->pg + 0x250),
		    *(uint32_t *)(this->pg + 0x270));
	}
}

fbt:vmm-restore:vlapic_process_eoi:entry /go/
{
	this->vl = arg0; this->cpu = *(int *)(this->vl + 16);
	this->pg = *(uintptr_t *)(this->vl + 24);
	@eoi[this->cpu] = count();
	self->ecpu = this->cpu + 1;
	self->epg = this->pg;
	self->eppr = *(uint32_t *)(this->pg + 0xa0);
	self->eisr5 = *(uint32_t *)(this->pg + 0x150);
	self->eisr7 = *(uint32_t *)(this->pg + 0x170);
}
fbt:vmm-restore:vlapic_process_eoi:return /self->ecpu && (self->eisr5 || self->eisr7)/
{
	printf("%10d EOI  LP%d prima: ppr=%#x isr5=%#x isr7=%#x  dopo: ppr=%#x isr5=%#x isr7=%#x\n",
	    (timestamp - t0) / 1000, self->ecpu - 1, self->eppr, self->eisr5,
	    self->eisr7, *(uint32_t *)(self->epg + 0xa0),
	    *(uint32_t *)(self->epg + 0x150), *(uint32_t *)(self->epg + 0x170));
}
fbt:vmm-restore:vlapic_process_eoi:return /self->ecpu/ { self->ecpu = 0; }

/* ---- l'ancora: i tick ---- */
vmm:vmx:nested:diag_entry { self->exp = arg4; self->dus = (timestamp - t0) / 1000; }
vmm:vmx:nested:diag_exit
{
	printf("%10d TICK VP%d exp=%d wall=%d\n", self->dus, (int)arg0, self->exp,
	    walltimestamp);
	@tick[(int)arg0] = count();
}

tick-10s /go/
{
	printf("=== %d s  wall=%d\n", (timestamp - t0) / 1000000000, walltimestamp);
	printa("  COERENZA LP%d ppr_non_nullo=%d isr_impostato=%d = %@d\n", @coer);
	printa("  ppr/isr  LP%d classe_ppr=%#x top_isr=%d = %@d\n", @pprclass);
	printa("  TPR      LP%d = %#x : %@d\n", @tprv);
	printa("  LVT      LP%d vett %#x = %@d\n", @lvt);
	printa("  LVT ult  LP%d vett %#x = %@d us\n", @lvt_ult);
	printa("  callout  LP%d = %@d\n", @callout);
	printa("  IOAPIC   vett %#x = %@d\n", @ioapic);
	printa("  MSI      vett %#x = %@d\n", @msi);
	printa("  accepted LP%d vett %#x = %@d\n", @acc);
	printa("  EOI      LP%d = %@d\n", @eoi);
	printa("  tick     VP%d = %@d\n", @tick);
}
