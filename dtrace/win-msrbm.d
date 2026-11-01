#pragma D option quiet
#pragma D option switchrate=4hz
/*
 * Claude 20/10/2026: la bitmap MSR dell'L1 (Hyper-V) chiede le uscite per gli
 * MSR che la bitmap dell'L0 lascia passare? Il VMCS02 usa SOLO quella dell'L0
 * (vmx_nested.c ~3317, fusione T6.3 mai fatta). Sola lettura.
 * Offset da DWARF: vmx_vcpu.nested +0x2b8; vmx_nested.current_vmcs12 +16,
 * cache[4] +24, sizeof(vmcs12_cache)=4384; vmcs12_cache.bm_msr +4152.
 * Bitmap: read-low 0, read-high 1024, write-low 2048, write-high 3072.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

vmm:vmx:nested:compose /go/
{
	this->n = *(uintptr_t *)(arg0 + 0x2b8);
	this->cur = *(uint64_t *)(this->n + 16);
	this->c = (uintptr_t)0;
	this->c = *(uint64_t *)(this->n + 24 + 0*4384) == this->cur ? this->n + 24 + 0*4384 : this->c;
	this->c = *(uint64_t *)(this->n + 24 + 1*4384) == this->cur ? this->n + 24 + 1*4384 : this->c;
	this->c = *(uint64_t *)(this->n + 24 + 2*4384) == this->cur ? this->n + 24 + 2*4384 : this->c;
	this->c = *(uint64_t *)(this->n + 24 + 3*4384) == this->cur ? this->n + 24 + 3*4384 : this->c;
	this->bm = this->c ? *(uintptr_t *)(this->c + 4152) : 0;
}

vmm:vmx:nested:compose /go && this->bm == 0/
{
	@nobm[this->cur] = count();
}

vmm:vmx:nested:compose /go && this->bm != 0/
{
	this->wefer  = *(uint8_t *)(this->bm + 3072 + 16) & 1;
	this->refer  = *(uint8_t *)(this->bm + 1024 + 16) & 1;
	this->wfsgs  = *(uint8_t *)(this->bm + 3072 + 32) & 3;	/* FS, GS base */
	this->rfsgs  = *(uint8_t *)(this->bm + 1024 + 32) & 3;
	this->wsyse  = (*(uint8_t *)(this->bm + 2048 + 46) >> 4) & 7;	/* SYSENTER CS/ESP/EIP */
	this->rsyse  = (*(uint8_t *)(this->bm + 0 + 46) >> 4) & 7;
	this->rtsc   = *(uint8_t *)(this->bm + 0 + 2) & 1;
	this->rtscx  = (*(uint8_t *)(this->bm + 1024 + 32) >> 3) & 1;	/* TSC_AUX */
	/* byte grezzi: high[16] = c0000080..87 (EFER bit0, STAR 1, LSTAR 2, CSTAR 3, SFMASK 4);
	 * high[32] = c0000100..107 (FS 0, GS 1, KGS 2, TSC_AUX 3) */
	@raw[this->cur, *(uint8_t *)(this->bm + 1024 + 16), *(uint8_t *)(this->bm + 3072 + 16),
	    *(uint8_t *)(this->bm + 1024 + 32), *(uint8_t *)(this->bm + 3072 + 32)] = count();
	@bm[this->cur, this->wefer, this->refer, this->wfsgs, this->rfsgs,
	    this->wsyse, this->rsyse, this->rtsc, this->rtscx] = count();
}

tick-10s /go/
{
	printf("=== %ds ===\n", (timestamp - t0)/1000000000);
	printa("  vmcs12=%#lx  W_EFER=%d R_EFER=%d  W_FSGS=%#x R_FSGS=%#x  W_SYSENTER=%#x R_SYSENTER=%#x  R_TSC=%d R_TSCAUX=%d : %@d\n", @bm);
	printa("  vmcs12=%#lx  RAW R[c0000080]=%#x W[c0000080]=%#x R[c0000100]=%#x W[c0000100]=%#x : %@d\n", @raw);
	printa("  vmcs12=%#lx  bitmap NON mappata : %@d\n", @nobm);
}
