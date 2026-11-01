#pragma D option quiet
#pragma D option switchrate=10hz
/* Ciclo di EPT violation dell'L2: stesso GPA che va in fault di continuo sullo stesso vCPU.
 * Alla 20a volta stampa: qual, esito vmx_vept_fault, l1gpa, perm EPT12, voce shadow per livello.
 * vmx_vcpu.nested +696; vmx_nested.vept_root +17720. DMAP 0xfffff80000000000. */
int cnt[int, uint64_t];
fbt:vmm-restore:vmx_vept_fault:entry { self->v = arg0; self->gpa = arg1; self->q = arg2; self->pl1 = arg3; self->pp = arg4; self->in = 1; }
fbt:vmm-restore:vmx_vept_fault:return /self->in/ {
	self->r = arg1; cnt[tid, self->gpa & ~0xfffULL]++;
	@tot[self->r] = count();
}
fbt:vmm-restore:vmx_vept_fault:return /self->in && cnt[tid, self->gpa & ~0xfffULL] == 20/ {
	this->n = *(uintptr_t *)(self->v + 696);
	this->root = *(uintptr_t *)(this->n + 17720);
	this->g = self->gpa;
	this->e3 = *(uint64_t *)(this->root + 8 * ((this->g >> 39) & 511));
	this->t2 = 0xfffff80000000000ULL + (this->e3 & 0x000ffffffffff000ULL);
	this->e2 = (this->e3 & 7) ? *(uint64_t *)(this->t2 + 8 * ((this->g >> 30) & 511)) : 0;
	this->t1 = 0xfffff80000000000ULL + (this->e2 & 0x000ffffffffff000ULL);
	this->e1 = (this->e2 & 7) ? *(uint64_t *)(this->t1 + 8 * ((this->g >> 21) & 511)) : 0;
	this->t0 = 0xfffff80000000000ULL + (this->e1 & 0x000ffffffffff000ULL);
	this->e0 = (this->e1 & 7) ? *(uint64_t *)(this->t0 + 8 * ((this->g >> 12) & 511)) : 0;
	printf("%Y t%d CICLO gpa=%#lx qual=%#lx esito=%d l1gpa=%#lx perm12=%#lx | shadow L4=%#lx L3=%#lx L2=%#lx L1=%#lx\n",
	    walltimestamp, tid, self->gpa, self->q, (int)self->r, *(uint64_t *)self->pl1, *(uint64_t *)self->pp,
	    this->e3, this->e2, this->e1, this->e0);
}
fbt:vmm-restore:vmx_vept_fault:return { self->in = 0; }
fbt:vmm-restore:vmx_vept_flush:entry { @fl = count(); }
fbt:vmm-restore:vmx_vept_invept:entry { @inv = count(); }
tick-10s { printa("  esiti vmx_vept_fault %d: %@d\n", @tot); printa("  flush shadow: %@d\n", @fl); printa("  invept: %@d\n", @inv); }
