#pragma D option quiet
#pragma D option switchrate=4hz
#pragma D option bufsize=32m
/*
 * Claude 20/10/2026 -- HYPERVISOR_ERROR (0x20001, P1=6 P2=4) all'avvio della VM
 * di WSL. Ipotesi: la cache dei VMCS12 (4 posti per vCPU, contenuto SOLO in
 * cache) sfratta o perde un VMCS12 di Hyper-V; oppure un VMfail inatteso.
 * Sola lettura, sonde fbt sul modulo 357ea55.
 * win-err12.d (parere #22): in piu', per ogni VMfail istruzione VMX (motivo d'uscita dell'L1),
 * encoding del campo (registro indicato da exit_insn_info[31:28]), slot e nfields del VMCS12
 * corrente; e il massimo nfields per VMCS12 (il limite e' 256).
 * Offset (DWARF 357ea55): vmx_vcpu.vcpu +8, ctx +0x68; vcpu.exitinfo +0x88; vm_exit.rip +8,
 * u.vmx.exit_reason +0x14; vmx_nested.exit_insn_info +18080; vmcs12_cache.nfields +4128.
 * Offset: vmx_vcpu.nested +0x2b8, vcpuid +0x2c0; vmx_nested.current_vmcs12 +16,
 * cache[i] = +24 + i*4384; vmcs12_cache.vmcs12_gpa +0, launched +20.
 */
int go; int64_t t0;
uint64_t g[int, int]; int seen[uint64_t];

vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 wall=%d\n", walltimestamp); }
vmm:vmx:nested:enter_l2 { @ingr[*(int *)(arg0 + 0x2c0)] = count(); }

/* ogni istruzione VMX dell'L1 finisce qui: confronta la cache con l'ultima vista */
fbt::nested_vmx_result:entry
{
	this->v = *(int *)(arg0 + 0x2c0);
	this->n = *(uintptr_t *)(arg0 + 0x2b8);
	this->cur = *(uint64_t *)(this->n + 16);
	self->ms = go ? (timestamp - t0) / 1000000 : 0;
}
fbt::vmx_nested_exit:entry
{
	this->ve = *(uintptr_t *)(arg0 + 8) + 0x88;
	self->rs = *(uint32_t *)(this->ve + 0x14) & 0xffff;
	self->l1rip = *(uint64_t *)(this->ve + 8);
}
/* slot del VMCS12 corrente e suo nfields */
fbt::nested_vmx_result:entry
{
	this->s = -1;
	this->s = *(uint64_t *)(this->n + 24 + 0*4384) == this->cur ? 0 : this->s;
	this->s = *(uint64_t *)(this->n + 24 + 1*4384) == this->cur ? 1 : this->s;
	this->s = *(uint64_t *)(this->n + 24 + 2*4384) == this->cur ? 2 : this->s;
	this->s = *(uint64_t *)(this->n + 24 + 3*4384) == this->cur ? 3 : this->s;
	this->nf = this->s >= 0 ? *(int *)(this->n + 24 + this->s*4384 + 4128) : -1;
}
fbt::nested_vmx_result:entry /this->s >= 0/ { @maxnf[this->cur] = max(this->nf); }
fbt::nested_vmx_result:entry /arg1 != 0/
{
	this->ii = *(uint64_t *)(this->n + 18080);
	this->r = (this->ii >> 28) & 0xf;
	this->ctx = arg0 + 0x68;
	this->off = this->r == 0 ? 48 : this->r == 1 ? 24 : this->r == 2 ? 16 : this->r == 3 ? 56 :
	    this->r == 5 ? 64 : this->r == 6 ? 8 : this->r == 7 ? 0 : this->r == 8 ? 32 :
	    this->r == 9 ? 40 : this->r >= 10 ? 72 + (this->r - 10) * 8 : -1;
	this->enc = this->off >= 0 ? *(uint64_t *)(this->ctx + this->off) : 0xdead;
	printf("%8d ms VP%d VMFAIL VALID err=%d insn(reason)=%d enc=%#lx (reg%d) cur=%#lx slot=%d nfields=%d l1rip=%#lx\n",
	    self->ms, this->v, (int)arg1, self->rs, (self->rs == 23 || self->rs == 25) ? this->enc : 0,
	    (int)this->r, this->cur, this->s, this->nf, self->l1rip);
	@fail[this->v, (int)arg1] = count();
	@failenc[(int)arg1, self->rs, (self->rs == 23 || self->rs == 25) ? this->enc : 0, this->nf] = count();
}
/* uno per slot, srotolato */
fbt::nested_vmx_result:entry
/ (this->a0 = *(uint64_t *)(this->n + 24 + 0*4384)) != g[this->v, 0] /
{ printf("%8d ms VP%d slot0 %#lx -> %#lx (launched=%d) cur=%#lx\n", self->ms, this->v, g[this->v, 0], this->a0, *(int *)(this->n + 24 + 0*4384 + 20), this->cur); g[this->v, 0] = this->a0; }
fbt::nested_vmx_result:entry
/ (this->a1 = *(uint64_t *)(this->n + 24 + 1*4384)) != g[this->v, 1] /
{ printf("%8d ms VP%d slot1 %#lx -> %#lx (launched=%d) cur=%#lx\n", self->ms, this->v, g[this->v, 1], this->a1, *(int *)(this->n + 24 + 1*4384 + 20), this->cur); g[this->v, 1] = this->a1; }
fbt::nested_vmx_result:entry
/ (this->a2 = *(uint64_t *)(this->n + 24 + 2*4384)) != g[this->v, 2] /
{ printf("%8d ms VP%d slot2 %#lx -> %#lx (launched=%d) cur=%#lx\n", self->ms, this->v, g[this->v, 2], this->a2, *(int *)(this->n + 24 + 2*4384 + 20), this->cur); g[this->v, 2] = this->a2; }
fbt::nested_vmx_result:entry
/ (this->a3 = *(uint64_t *)(this->n + 24 + 3*4384)) != g[this->v, 3] /
{ printf("%8d ms VP%d slot3 %#lx -> %#lx (launched=%d) cur=%#lx\n", self->ms, this->v, g[this->v, 3], this->a3, *(int *)(this->n + 24 + 3*4384 + 20), this->cur); g[this->v, 3] = this->a3; }

fbt::nested_vmfail_invalid:entry
{
	printf("%8d ms VP%d VMFAIL INVALID cur=%#lx\n", go ? (timestamp - t0) / 1000000 : 0,
	    *(int *)(arg0 + 0x2c0), *(uint64_t *)(*(uintptr_t *)(arg0 + 0x2b8) + 16));
	@finv[*(int *)(arg0 + 0x2c0)] = count();
}

/* VMLAUNCH (non resume): un VMCS12 nuovo che parte */
fbt::nested_vmlaunch:entry /arg1 == 0/
{
	this->c = *(uint64_t *)(*(uintptr_t *)(arg0 + 0x2b8) + 16);
	@launch[*(int *)(arg0 + 0x2c0), this->c] = count();
}
fbt::nested_vmlaunch:entry /arg1 == 0 && !seen[this->c]/
{
	seen[this->c] = 1;
	printf("%8d ms VP%d primo VMLAUNCH di %#lx\n", go ? (timestamp - t0) / 1000000 : 0,
	    *(int *)(arg0 + 0x2c0), this->c);
}
fbt::nested_vmlaunch:entry { @vmc[*(int *)(arg0 + 0x2c0), *(uint64_t *)(*(uintptr_t *)(arg0 + 0x2b8) + 16)] = count(); }

/* MSR di crash sintetici della root (codice + P1..P4) */
fbt::nested_l2_exit:entry
/(*(uint32_t *)(arg1 + 20) & 0xffff) == 32 &&
 (*(uint64_t *)(arg0 + 0x68 + 24) & 0xffffffff) >= 0x40000100 &&
 (*(uint64_t *)(arg0 + 0x68 + 24) & 0xffffffff) <= 0x40000105/
{
	printf("%8d ms VP%d WRMSR crash %#x = %#lx\n", (timestamp - t0) / 1000000, *(int *)(arg0 + 704),
	    (int)(*(uint64_t *)(arg0 + 0x68 + 24) & 0xffffffff),
	    ((*(uint64_t *)(arg0 + 0x68 + 16) & 0xffffffff) << 32) | (*(uint64_t *)(arg0 + 0x68 + 48) & 0xffffffff));
}

tick-10s /go/
{
	printf("=== %d s ===\n", (timestamp - t0) / 1000000000);
	printa("  ingressi L2 VP%d %@d\n", @ingr);
	printa("  VMfail valid VP%d err=%d : %@d\n", @fail);
	printa("  VMfail invalid VP%d : %@d\n", @finv);
	printa("  VMfail err=%d reason=%d enc=%#lx nfields=%d : %@d\n", @failenc);
	printa("  max nfields vmcs12=%#lx : %@d\n", @maxnf);
	printa("  VMLAUNCH+VMRESUME VP%d vmcs12=%#lx : %@d\n", @vmc);
}
