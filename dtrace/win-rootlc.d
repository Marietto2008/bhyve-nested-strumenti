#pragma D option quiet
#pragma D option bufsize=48m
#pragma D option aggsize=16m
#pragma D option switchrate=2hz
#pragma D option dynvarsize=8m
/*
 * Claude 19/10/2026 -- Astra #9 "win-root-lifecycle": il confine root L2 -> hypervisor L1.
 * SOLO sonde con argomenti verificati (NB: vmm:vmx:exit:entry ha arg0 = struct vmx della VM,
 * NON il vmx_vcpu: i tracer che leggevano arg0+696/+0x68 li' erano sbagliati).
 *   nested_l2_exit(struct vmx_vcpu *vcpu, struct vm_exit *vmexit): scatta SOLO per uscite di L2.
 *     vcpu: vcpuid +704, ctx +0x68 (rdi+0 rsi+8 rdx+16 rcx+24 r8+32 r9+40 rax+48)
 *     vmexit: rip +8, exit_reason +20, exit_qualification +24
 *   nested:compose(vcpu, VMCS12 ENTRY_INTR_INFO, pin, proc, RFLAGS<<32|interruptibility)
 *   nested:eptviol(vcpu, eptp hw, eptp shadow, gpa, qual)
 *   nested:reflect(vcpu): l'uscita viene riflessa a L1
 * Registra: MSR (31/32) con indice e valore, APIC-access (44), VMCALL (18) con codice
 * hypercall, HLT (12), accessi EPT alla pagina APIC 0xfee00000, interrupt iniettati in L2 agli
 * ingressi, esito (riflessa/L0) dell'ultima uscita significativa, e ogni secondo l'ultima
 * operazione di ciascun VP.
 */
int go; int64_t t0;
int64_t lt[int]; int lr[int]; uint64_t lrip[int];
int64_t st[int]; int sr[int]; uint64_t srip[int]; uint64_t sarg[int]; uint64_t sval[int]; int sout[int];
int64_t et[int]; uint64_t einj[int]; int64_t ijt[int]; uint64_t ijv[int];
int64_t idt[int];

vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

fbt:vmm-restore:nested_l2_exit:entry /go/
{
	this->cpu = *(int *)(arg0 + 704);
	this->r = *(uint32_t *)(arg1 + 20) & 0xffff;
	this->rip = *(uint64_t *)(arg1 + 8);
	this->q = *(uint64_t *)(arg1 + 24);
	this->rcx = *(uint64_t *)(arg0 + 0x68 + 24);
	this->rax = *(uint64_t *)(arg0 + 0x68 + 48);
	this->rdx = *(uint64_t *)(arg0 + 0x68 + 16);
	this->msr = this->rcx & 0xffffffff;
	this->val = ((this->rdx & 0xffffffff) << 32) | (this->rax & 0xffffffff);
	@why[this->cpu, this->r] = count();
	lt[this->cpu] = timestamp; lr[this->cpu] = this->r; lrip[this->cpu] = this->rip;
	self->in = 1; self->refl = 0; self->sig = 0; self->cpu = this->cpu; self->rip = this->rip;
}

/* RDMSR/WRMSR della root: conteggio per indice; stampa dei registri di tempo/interrupt */
fbt:vmm-restore:nested_l2_exit:entry /go && (this->r == 31 || this->r == 32)/
{
	@msr[this->cpu, this->r == 32 ? "WR" : "RD", this->msr] = count();
	self->sig = 1;
	st[this->cpu] = timestamp; sr[this->cpu] = this->r; srip[this->cpu] = this->rip;
	sarg[this->cpu] = this->msr; sval[this->cpu] = this->val;
}
fbt:vmm-restore:nested_l2_exit:entry
/go && (this->r == 31 || this->r == 32) &&
 (this->msr == 0x6e0 || (this->msr >= 0x830 && this->msr <= 0x83f) ||
  (this->msr >= 0x40000000 && this->msr <= 0x400000ef && this->msr != 0x40000070))/
{
	printf("%10d cpu%d L2 %s msr=%#x val=%#lx rip=%#lx\n", (timestamp - t0)/1000, this->cpu,
	    this->r == 32 ? "WRMSR" : "RDMSR", this->msr, this->val, this->rip);
}
/* GUEST_IDLE: solo l'ultimo istante per VP (frequente) */
fbt:vmm-restore:nested_l2_exit:entry /go && this->r == 31 && this->msr == 0x400000f0/
{ idt[this->cpu] = timestamp; }

/* APIC-access (44): offset + tipo; stampa timer/ICR/LVT */
fbt:vmm-restore:nested_l2_exit:entry /go && this->r == 44/
{
	@apic[this->cpu, this->q & 0xfff, (this->q >> 12) & 0xf] = count();
	self->sig = 1;
	st[this->cpu] = timestamp; sr[this->cpu] = 44; srip[this->cpu] = this->rip;
	sarg[this->cpu] = this->q & 0xfff; sval[this->cpu] = (this->q >> 12) & 0xf;
}
fbt:vmm-restore:nested_l2_exit:entry
/go && this->r == 44 && ((this->q & 0xfff) == 0x320 || (this->q & 0xfff) == 0x380 ||
 (this->q & 0xfff) == 0x3e0 || (this->q & 0xfff) == 0x300)/
{
	printf("%10d cpu%d L2 APIC-ACCESS off=%#x tipo=%d rip=%#lx\n", (timestamp - t0)/1000,
	    this->cpu, this->q & 0xfff, (this->q >> 12) & 0xf, this->rip);
}

/* VMCALL (18): codice hypercall nei bit 15:0 di RCX */
fbt:vmm-restore:nested_l2_exit:entry /go && this->r == 18/
{
	@hc[this->cpu, this->rcx & 0xffff] = count();
	self->sig = 1;
	st[this->cpu] = timestamp; sr[this->cpu] = 18; srip[this->cpu] = this->rip;
	sarg[this->cpu] = this->rcx; sval[this->cpu] = 0;
}

/* HLT eseguito da L2 */
fbt:vmm-restore:nested_l2_exit:entry /go && this->r == 12/
{
	printf("%10d cpu%d L2 HLT rip=%#lx\n", (timestamp - t0)/1000, this->cpu, this->rip);
	self->sig = 1;
	st[this->cpu] = timestamp; sr[this->cpu] = 12; srip[this->cpu] = this->rip;
	sarg[this->cpu] = 0; sval[this->cpu] = 0;
}

/* violazioni EPT di L2 sulla pagina APIC */
vmm:vmx:nested:eptviol /go && arg3 >= 0xfee00000 && arg3 < 0xfef00000/
{
	printf("%10d cpu%d L2 EPT-APIC gpa=%#lx qual=%#lx rip=%#lx\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 704), arg3, arg4, self->rip);
}

vmm:vmx:nested:reflect /self->in/ { self->refl = 1; }

fbt:vmm-restore:nested_l2_exit:return /self->in/
{
	@out[self->cpu, self->refl ? "riflessa" : "L0"] = count();
	if (self->sig) sout[self->cpu] = self->refl;
	self->in = 0;
}

/* ingresso in L2: interrupt iniettato dal VMCS12 */
vmm:vmx:nested:compose /go/
{
	this->cpu = *(int *)(arg0 + 704);
	et[this->cpu] = timestamp; einj[this->cpu] = arg1;
	@ent[this->cpu] = count();
}
vmm:vmx:nested:compose /go && (arg1 & 0x80000000)/
{
	this->cpu = *(int *)(arg0 + 704);
	ijt[this->cpu] = timestamp; ijv[this->cpu] = arg1;
	@inj[this->cpu, arg1 & 0xff, (arg1 >> 8) & 7] = count();
}

tick-1s /go/
{
	printf("=== %ds\n", (timestamp - t0)/1000000000);
	printf("  VP0: ultima uscita %dms fa r=%d rip=%#lx | ultima signif. %dms fa r=%d arg=%#lx val=%#lx esito=%s rip=%#lx | ingresso %dms fa | ultimo iniettato %dms fa info=%#lx | guest_idle %dms fa\n",
	    lt[0] ? (timestamp - lt[0])/1000000 : -1, lr[0], lrip[0],
	    st[0] ? (timestamp - st[0])/1000000 : -1, sr[0], sarg[0], sval[0], sout[0] ? "riflessa" : "L0", srip[0],
	    et[0] ? (timestamp - et[0])/1000000 : -1,
	    ijt[0] ? (timestamp - ijt[0])/1000000 : -1, ijv[0],
	    idt[0] ? (timestamp - idt[0])/1000000 : -1);
	printf("  VP1: ultima uscita %dms fa r=%d rip=%#lx | ultima signif. %dms fa r=%d arg=%#lx val=%#lx esito=%s rip=%#lx | ingresso %dms fa | ultimo iniettato %dms fa info=%#lx | guest_idle %dms fa\n",
	    lt[1] ? (timestamp - lt[1])/1000000 : -1, lr[1], lrip[1],
	    st[1] ? (timestamp - st[1])/1000000 : -1, sr[1], sarg[1], sval[1], sout[1] ? "riflessa" : "L0", srip[1],
	    et[1] ? (timestamp - et[1])/1000000 : -1,
	    ijt[1] ? (timestamp - ijt[1])/1000000 : -1, ijv[1],
	    idt[1] ? (timestamp - idt[1])/1000000 : -1);
}

tick-10s /go/
{
	printa("  usc cpu%d motivo %d: %@d\n", @why);
	printa("  msr cpu%d %s %#x: %@d\n", @msr);
	printa("  apic cpu%d off %#x tipo %d: %@d\n", @apic);
	printa("  hcall cpu%d codice %#x: %@d\n", @hc);
	printa("  iniettato cpu%d vett %#x tipo %d: %@d\n", @inj);
	printa("  ingressi cpu%d: %@d\n", @ent);
	printa("  esito cpu%d %s: %@d\n", @out);
	trunc(@why); trunc(@msr); trunc(@apic); trunc(@hc); trunc(@inj); trunc(@ent); trunc(@out);
}
