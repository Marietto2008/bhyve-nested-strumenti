#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Astra #4: modello temporale. Ogni cambio dell'offset
 * TSC L0->L1 (vmx_set_tsc_offset) e ogni scrittura IA32_TSC (MSR 0x10) dal
 * guest, con in_l2 (chi scrive: L1 o L2). Conta anche gli eventuali RDTSC
 * (reason 16) / RDTSCP (51) intercettati. Sospetto (vmx_nested.c:2081): una
 * scrittura IA32_TSC fa l1_tsc_offset = val - rdtsc(), spostando la base di
 * L1 anche se a scriverla e' L2 -> TSC non monotono alla transizione.
 * Offset: vmx_vcpu vcpuid+704, nested+696 (in_l2+1), rcx+128, rax+152, rdx+120;
 * vmexit+20 reason. exit:entry arg1=vcpuid.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

fbt:vmm-restore:vmx_set_tsc_offset:entry /go/
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->l2 = this->n ? *(uint8_t *)(this->n + 1) : 0;
	printf("%10d cpu%d SET-TSC-OFF off=%#lx in_l2=%d\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 704), (uint64_t)arg1, this->l2);
}

vmm:vmx:exit:entry /go/
{
	this->r = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	this->rcx = *(uint64_t *)(arg0 + 128) & 0xffffffff;
	this->n = *(uintptr_t *)(arg0 + 696);
	this->l2 = this->n ? *(uint8_t *)(this->n + 1) : 0;
	if (this->r == 32 && this->rcx == 0x10) {
		this->v = ((*(uint64_t *)(arg0 + 120) & 0xffffffff) << 32) |
		    (*(uint64_t *)(arg0 + 152) & 0xffffffff);
		printf("%10d cpu%d WRMSR IA32_TSC=%#lx in_l2=%d\n", (timestamp - t0)/1000,
		    (int)arg1, this->v, this->l2);
	}
	if (this->r == 16) @rd[(int)arg1] = count();
	if (this->r == 51) @rdp[(int)arg1] = count();
}

tick-5s /go/
{
	printf("--- %ds | RDTSC-exit e RDTSCP-exit per cpu:\n", (timestamp - t0)/1000000000);
	printa("    rdtsc cpu%d = %@d\n", @rd);
	printa("    rdtscp cpu%d = %@d\n", @rdp);
}
