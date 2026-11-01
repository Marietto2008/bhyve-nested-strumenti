#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option aggrate=50hz
#pragma D option dynvarsize=8m
#pragma D option bufsize=8m
/* Claude 24/10/2026: COPIA per il modulo 19fc4ebf6189 (shadow VMCS v2): vmx_nested.vept_eptp12 +17792
 * (era +17760) ed exit_insn_info +0x46c8 (era +0x46a8), dal DWARF; vmx_vcpu invariato. */
/*
 * Claude 23/10/2026 -- parere #36, versione A CAMPIONAMENTO di partdiag.d. La prima
 * versione scattava a ogni uscita (decine di migliaia al secondo per vCPU) e ha piu'
 * che triplicato la compilazione: misurato con profile-997, il 20% dei campioni dei
 * thread vCPU cadeva dentro DTrace stesso.
 * Qui: profile-997 su ogni CPU; se il thread interrotto e' un vCPU di bhyve:
 *  - "guest" se il campione cade in vmx_call_isr: bhyve usa l'acknowledge-on-exit e
 *    consegna l'interrupt dell'host da li', quindi la CPU stava eseguendo il guest
 *    quando il timer e' scattato;
 *  - altrimenti "L0" (bhyve, kernel dell'host);
 *  - contesto letto in quel momento: nested->in_l2 ? nested->vept_eptp12 : 0 (L1);
 *    per un campione "guest" e' il contesto che girava (l'uscita non e' ancora stata
 *    elaborata).
 * Fuori CPU: sched:::off-cpu/on-cpu dei soli thread vCPU (eventi rari), attribuito al
 * contesto al momento dell'uscita dalla CPU (in L1 = tipicamente HLT dell'L1).
 * Il puntatore al vCPU si prende una volta per thread da nested:enter_l2.
 * Uscita ogni 100 ms: "T <ns>" e righe "  v<vcpu> <ctx> guest <campioni> l0 <campioni>
 * fuori <us>"; un campione vale ~1 ms (997 Hz). Ogni 60 s le funzioni di L0 per contesto.
 * Offset (DWARF 66a1ae3): vmx_vcpu.nested +696, .vcpuid +704; vmx_nested.in_l2 +1,
 * .vept_eptp12 +17760.
 */
self uintptr_t vp;
self uint64_t toff, offctx;
self int v;

vmm:vmx:nested:enter_l2 /self->vp == 0/
{
	self->vp = arg0;
	self->v = *(int *)(arg0 + 704);
}

profile-997 /self->vp/
{
	this->n = *(uintptr_t *)(self->vp + 696);
	this->ctx = this->n != 0 && *(uint8_t *)(this->n + 1) ?
	    *(uint64_t *)(this->n + 17792) : 0;
	this->g = arg0 >= (uint64_t)&`vmx_call_isr && arg0 < (uint64_t)&`vmx_call_isr + 0x17;
}
profile-997 /self->vp && this->g/ { @gu[self->v, this->ctx] = count(); }
profile-997 /self->vp && !this->g && arg0 != 0/
{
	@l0[self->v, this->ctx] = count();
	@fn[this->ctx, func(arg0)] = count();
}

sched:::off-cpu /self->vp/
{
	this->n = *(uintptr_t *)(self->vp + 696);
	self->offctx = this->n != 0 && *(uint8_t *)(this->n + 1) ?
	    *(uint64_t *)(this->n + 17792) : 0;
	self->toff = timestamp;
}
sched:::on-cpu /self->vp && self->toff/
{
	@off[self->v, self->offctx] = sum((timestamp - self->toff) / 1000);
	self->toff = 0;
}

tick-100ms
{
	printf("T %d\n", walltimestamp);
	printa("  v%d %#lx guest %@d l0 %@d fuori %@d\n", @gu, @l0, @off);
	trunc(@gu); trunc(@l0); trunc(@off);
}
tick-60s
{
	printf("##### %Y funzioni di L0 per contesto (campioni):\n", walltimestamp);
	trunc(@fn, 40);
	printa("    %#lx %-40a %@d\n", @fn);
	trunc(@fn);
}
