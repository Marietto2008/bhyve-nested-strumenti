#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option dynvarsize=32m
#pragma D option bufsize=16m
#pragma D option aggsize=4m
/*
 * Claude 23/10/2026 -- parere #36 §2/§3/§5: per ogni thread vCPU di bhyve, ricostruisce la
 * RESIDENZA effettiva nei contesti, non solo gli ingressi:
 *  - guest: dall'ingresso (fbt nested_diag_pre_entry, chiamata subito prima di
 *    vmx_enter_guest) all'uscita (vmm:vmx:exit:entry, inizio di vmx_exit_process);
 *    contesto = EPTP12 della shadow (nested->vept_eptp12) se il vCPU e' in L2,
 *    altrimenti 0 = L1;
 *  - L0: dall'uscita al successivo ingresso, attribuito al contesto dell'uscita, diviso
 *    in sulla CPU e fuori CPU (sched:::off-cpu/on-cpu del thread), e separando le uscite
 *    HLT dell'L1 (vCPU dell'L1 inattivo);
 *  - uscite per contesto, e il motivo dell'ultima uscita riflessa all'L1 di ogni
 *    contesto L2 (vmm:vmx:nested:reflect): 12 = HLT, 1 = interrupt esterno, ecc.
 * Le categorie sono esclusive per costruzione: ogni nanosecondo del thread, fra un
 * ingresso e il successivo, cade in guest(ctx), L0 sulla CPU (ctx) o L0 fuori CPU (ctx).
 * Uscita:
 *  - ogni 100 ms una riga "T <ns di parete>" e, per vCPU e contesto,
 *    "  v<vcpu> <ctx> guest <us> l0cpu <us> l0off <us> l0hlt <us> uscite <n>";
 *  - "ASSENTE <ctx> <ms> ... motivo <r>": un contesto L2 che rientra (su qualunque
 *    vCPU) dopo oltre 200 ms senza girare su nessuno, con il motivo della sua ultima
 *    uscita riflessa e l'ultimo vCPU che lo eseguiva;
 *  - "NUOVO <ctx> vmcs12 <gpa> vcpu <n>": prima comparsa di una coppia (EPTP12, VMCS12).
 * L'intervallo aperto: un guest esce almeno a ogni interrupt dell'host (hz=1000), quindi
 * la residenza non ancora chiusa a fine finestra e' al piu' ~1 ms; il massimo per uscita
 * e' in @maxres. CR3 dell'L2 non e' leggibile da DTrace (sta nel VMCS hardware).
 * Offset (DWARF di 66a1ae3, Build ID d6bb9ce9...): vmx_vcpu.nested +696, .vcpuid +704;
 * vmx_nested.in_l2 +1, .current_vmcs12 +16, .vept_eptp12 +17760; vm_exit.reason +20.
 */
self uint64_t ex, offacc, ent, toff, ctx, exctx;
self int v, isv, exhlt, exr;
uint64_t ctxlast[uint64_t];	/* ultima volta che il contesto ha girato (ns) */
int ctxvcpu[uint64_t];
int ctxrefl[uint64_t];		/* motivo dell'ultima uscita riflessa */
int visto[uint64_t, uint64_t];

fbt::nested_diag_pre_entry:entry
{
	this->n = *(uintptr_t *)(arg0 + 696);
	self->v = *(int *)(arg0 + 704);
	this->in = this->n != 0 ? *(uint8_t *)(this->n + 1) : 0;
	this->ctx = this->in ? *(uint64_t *)(this->n + 17760) : 0;
	this->now = timestamp;
	self->isv = 1;
}
/* chiusura dell'L0 precedente, attribuito al contesto dell'uscita */
fbt::nested_diag_pre_entry:entry /self->ex/
{
	this->w = this->now - self->ex;
	this->cpu = this->w > self->offacc ? this->w - self->offacc : 0;
	@l0c[self->v, self->exctx] = sum(this->cpu / 1000);
	@l0o[self->v, self->exctx] = sum(self->exhlt ? 0 : self->offacc / 1000);
	@l0h[self->v, self->exctx] = sum(self->exhlt ? self->offacc / 1000 : 0);
	self->ex = 0;
}
fbt::nested_diag_pre_entry:entry
{
	self->offacc = 0;
	self->ent = this->now;
	self->ctx = this->ctx;
}
/* un contesto L2 che torna dopo un'assenza su TUTTI i vCPU; ctxlast si legge UNA volta
 * (un altro vCPU puo' aggiornarlo fra il predicato e la stampa) */
fbt::nested_diag_pre_entry:entry
{
	this->last = this->ctx != 0 ? ctxlast[this->ctx] : 0;
}
fbt::nested_diag_pre_entry:entry
/this->last && this->now > this->last && this->now - this->last > 200000000/
{
	printf("ASSENTE %#lx %d ms fino a %Y.%03d rientra su v%d, prima su v%d, ultima uscita riflessa motivo %d\n",
	    this->ctx, (this->now - this->last) / 1000000, walltimestamp,
	    (walltimestamp % 1000000000) / 1000000, self->v, ctxvcpu[this->ctx],
	    ctxrefl[this->ctx]);
}
fbt::nested_diag_pre_entry:entry
/this->ctx != 0 && visto[this->ctx, *(uint64_t *)(this->n + 16)] == 0/
{
	visto[this->ctx, *(uint64_t *)(this->n + 16)] = 1;
	printf("NUOVO %#lx vmcs12 %#lx vcpu %d %Y\n", this->ctx,
	    *(uint64_t *)(this->n + 16), self->v, walltimestamp);
}

vmm:vmx:exit:entry /self->isv && self->ent/
{
	this->now = timestamp;
	this->r = *(uint32_t *)(arg2 + 20) & 0xffff;
	this->res = this->now - self->ent;
	@gu[self->v, self->ctx] = sum(this->res / 1000);
	@ex[self->v, self->ctx] = count();
	@maxres[self->ctx == 0 ? "L1" : "L2"] = max(this->res / 1000);
	@motivi[self->ctx, this->r] = count();
	ctxlast[self->ctx] = this->now;
	ctxvcpu[self->ctx] = self->v;
	self->ex = this->now;
	self->exctx = self->ctx;
	self->exhlt = (self->ctx == 0 && this->r == 12);
	self->exr = this->r;
	self->ent = 0;
}
vmm:vmx:nested:reflect /self->isv && self->exctx != 0/ { ctxrefl[self->exctx] = self->exr; }

sched:::off-cpu /self->isv && self->ex/ { self->toff = timestamp; }
sched:::on-cpu /self->isv && self->toff/
{
	self->offacc += timestamp - self->toff;
	self->toff = 0;
}

tick-100ms
{
	printf("T %d\n", walltimestamp);
	printa("  v%d %#lx guest %@d l0cpu %@d l0off %@d l0hlt %@d uscite %@d\n",
	    @gu, @l0c, @l0o, @l0h, @ex);
	trunc(@gu); trunc(@l0c); trunc(@l0o); trunc(@l0h); trunc(@ex);
}
tick-60s
{
	printf("##### %Y residenza massima per uscita (us):\n", walltimestamp);
	printa("  %s %@d\n", @maxres);
	printf("  uscite per contesto e motivo:\n");
	printa("    %#lx motivo %d: %@d\n", @motivi);
	trunc(@maxres); trunc(@motivi);
}
