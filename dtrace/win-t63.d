#pragma D option quiet
#pragma D option switchrate=4hz
#pragma D option bufsize=16m
/*
 * Claude 20/10/2026 -- verifica T6.3 (357ea55), parere #21 di Astra, prima corsa.
 * A. bitmap effettiva del VMCS02 (sonda msrbm): invarianti B02 = B01 | B12
 *    sui byte di EFER/STAR/LSTAR/CSTAR/SFMASK e SYSENTER, indirizzo, flag.
 * B. RDMSR/WRMSR dall'L2: decisione (riflessa all'L1 o gestita da L0) per MSR.
 * C. EFER del VMCS12/VMCS02 per (vmcs12, VTL) nel tempo (sonde efer/efer2,
 *    sysctl hw.vmm.vmx.diag_efer=1).
 * D. #UD in L2 (ud_a, sysctl hw.vmm.vmx.diag_ud=1) e vitalita' (ingressi).
 * Offset: vmx_vcpu.ctx +0x68 (rcx +24, rax +48, rdx +16); vm_exit.reason +20.
 */
int go; int64_t t0; int wr_efer;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 wall=%d\n", walltimestamp); }
vmm:vmx:nested:enter_l2 /go/ { @ingr = count(); @ultingr = max((timestamp - t0)/1000000); }

/* A */
vmm:vmx:nested:msrbm
{
	this->e = arg2; this->s = arg3;
	this->ok_e = ((this->e & 0xff) | ((this->e >> 16) & 0xff)) == ((this->e >> 32) & 0xff) &&
	    (((this->e >> 8) & 0xff) | ((this->e >> 24) & 0xff)) == ((this->e >> 40) & 0xff);
	this->ok_s = ((this->s & 0xff) | ((this->s >> 16) & 0xff)) == ((this->s >> 32) & 0xff) &&
	    (((this->s >> 8) & 0xff) | ((this->s >> 24) & 0xff)) == ((this->s >> 40) & 0xff);
	@bm[(int)arg0, arg4, this->e, this->s, this->ok_e && this->ok_s] = count();
	@pa[(int)arg0, arg1] = count();
}

/* B */
fbt::nested_l2_exit:entry
{
	self->r = *(uint32_t *)(arg1 + 20) & 0xffff;
	self->msr = *(uint64_t *)(arg0 + 0x68 + 24) & 0xffffffff;
	self->v = (*(uint64_t *)(arg0 + 0x68 + 16) << 32) | (*(uint64_t *)(arg0 + 0x68 + 48) & 0xffffffff);
}
fbt::nested_l2_exit:return /self->r == 31 || self->r == 32/
{
	/* arg1 = true: gestita qui = riflessa all'L1 */
	@msr[self->r == 32 ? "WRMSR" : "RDMSR", self->msr, (int)arg1] = count();
}
fbt::nested_l2_exit:return /go && self->r == 32 && self->msr == 0xc0000080 && wr_efer < 10/
{
	printf("%8d ms WRMSR EFER val=%#lx riflessa=%d\n", (timestamp - t0)/1000000, self->v, (int)arg1);
	wr_efer++;
}
fbt::nested_l2_exit:return { self->r = 0; }

/* C */
vmm:vmx:nested:efer { self->e12 = arg1; self->ld = (arg4 >> 15) & 1; }
vmm:vmx:nested:efer2 /go/
{
	@ef[arg3, arg1, self->e12, arg2, self->ld] = count();
	@efmin[arg3, arg1, self->e12, arg2, self->ld] = min((timestamp - t0)/1000000);
	@efmax[arg3, arg1, self->e12, arg2, self->ld] = max((timestamp - t0)/1000000);
}

/* D */
vmm:vmx:nested:ud_a /go/ { @ud = count(); printf("%8d ms #UD in L2 VP%d\n", (timestamp - t0)/1000000, (int)arg0); }

tick-10s /go/
{
	printf("=== %d s ===\n", (timestamp - t0)/1000000000);
	printa("  ingressi L2 %@d\n", @ingr); printa("  ultimo ingresso %@d ms\n", @ultingr);
	printa("  #UD %@d\n", @ud);
	printa("  BM VP%d flags=%#x efer=%#014lx syse=%#014lx invariante_ok=%d : %@d\n", @bm);
	printa("  BM VP%d VMCS02.MSR_BITMAP=%#lx : %@d\n", @pa);
	printa("  %s %#x riflessa=%d : %@d\n", @msr);
	printa("  EFER vmcs12=%#lx VTL=%#lx efer12=%#lx efer02=%#lx LOAD=%d : %@d\n", @ef);
	printa("  EFER vmcs12=%#lx VTL=%#lx efer12=%#lx efer02=%#lx LOAD=%d primo %@d ms\n", @efmin);
	printa("  EFER vmcs12=%#lx VTL=%#lx efer12=%#lx efer02=%#lx LOAD=%d ultimo %@d ms\n", @efmax);
}
