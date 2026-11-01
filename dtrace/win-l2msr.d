#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option aggsize=8m
#pragma D option switchrate=5hz
/*
 * Claude 19/10/2026 — Astra #4 priorita' 2: MSR sintetici di L2 (Windows root)
 * a livello di USCITA. I registri Hyper-V 0x40000000-0x400000FF sono FUORI dai
 * range del bitmap MSR VMX, quindi un RDMSR/WRMSR di L2 provoca SEMPRE un
 * VM-exit hardware a L0 (reason 31=RDMSR, 32=WRMSR), anche quando poi e'
 * riflesso a L1. Leggo RCX (indice MSR) e, per le scritture, EDX:EAX, dallo
 * stato del guest. Aggrego per (in_l2, reason, msr). Risponde: la root
 * programma timer sintetici (STIMER 0xB0-0xB7), SynIC (0x80-0x9F), legge
 * reference-TSC (0x20/0x21) o GUEST_IDLE (0xF0)?
 * Offset: vmx_vcpu rcx +128, rax +152, rdx +120, nested +696 (in_l2 +1);
 * vmexit +20 reason.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

vmm:vmx:exit:entry /go/
{
	this->r = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	this->rcx = *(uint64_t *)(arg0 + 128) & 0xffffffff;
	this->n = *(uintptr_t *)(arg0 + 696);
	this->l2 = this->n ? *(uint8_t *)(this->n + 1) : 0;
	if ((this->r == 31 || this->r == 32) &&
	    this->rcx >= 0x40000000 && this->rcx <= 0x400000ff) {
		@cnt[this->l2, this->r, this->rcx] = count();
		this->v = ((*(uint64_t *)(arg0 + 120) & 0xffffffff) << 32) |
		    (*(uint64_t *)(arg0 + 152) & 0xffffffff);
		if (this->r == 32)
			@wval[this->l2, this->rcx] = max(this->v);
	}
}

tick-5s /go/
{
	printf("=== %ds  MSR Hyper-V di L2/L1 (31=RD 32=WR):\n", (timestamp - t0)/1000000000);
	printa("  in_l2=%d r=%d msr=%#x : %@d\n", @cnt);
	printa("  WR in_l2=%d msr=%#x ultimo=%@#x\n", @wval);
}
