#pragma D option quiet
#pragma D option switchrate=10hz
/* EPT violation di L2: eptp hardware (VMCS02) vs shadow, per GPA. Se combaciano, il
 * problema NON e' l'EPTP; se differiscono, il ciclo nasce da li'. Alla 30a volta sullo
 * stesso GPA dumpa la voce shadow (vept_root +17720 nella nested +696). */
int cnt[uint64_t];
vmm:vmx:nested:eptviol {
	@match[arg1 == arg2 ? "eptp UGUALI" : "eptp DIVERSI"] = count();
	@acc[arg4 & 7] = count();
	@g[arg3 & ~0xfffULL] = count();
	cnt[arg3 & ~0xfffULL]++;
}
vmm:vmx:nested:eptviol /cnt[arg3 & ~0xfffULL] == 30/ {
	this->n = *(uintptr_t *)(arg0 + 696); this->root = *(uint64_t *)(this->n + 17720); this->g = arg3;
	this->e3 = *(uint64_t *)(0xfffff80000000000ULL + (this->root & 0x000ffffffffff000ULL) + 8*((this->g>>39)&511));
	this->t2 = 0xfffff80000000000ULL + (this->e3 & 0x000ffffffffff000ULL);
	this->e2 = (this->e3 & 7) ? *(uint64_t *)(this->t2 + 8*((this->g>>30)&511)) : 0;
	this->t1 = 0xfffff80000000000ULL + (this->e2 & 0x000ffffffffff000ULL);
	this->e1 = (this->e2 & 7) ? *(uint64_t *)(this->t1 + 8*((this->g>>21)&511)) : 0;
	this->t0 = 0xfffff80000000000ULL + (this->e1 & 0x000ffffffffff000ULL);
	this->e0 = (this->e1 & 7) ? *(uint64_t *)(this->t0 + 8*((this->g>>12)&511)) : 0;
	printf("CICLO gpa=%#lx qual=%#lx eptp_hw=%#lx eptp_shadow=%#lx %s | shadow L4=%#lx L3=%#lx L2=%#lx L1=%#lx\n",
	    arg3, arg4, arg1, arg2, arg1==arg2?"(uguali)":"(DIVERSI!)", this->e3, this->e2, this->e1, this->e0);
}
tick-15s { printf("--- riepilogo:\n"); printa("  %s: %@d\n", @match); printa("  accesso(R1W2X4) %d: %@d\n", @acc); trunc(@g); }
tick-15s /dur++ >= 240/ { exit(0); }
