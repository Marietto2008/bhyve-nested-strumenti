#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option switchrate=1hz
/* EPT violation dell'L2 che si RIPETONO (livelock a ogni tick). Per pagina GPA: alla 5a, 50a,
 * 500a volta stampa RIP, qual, eptp hw==shadow, voce shadow L4..L1; esiti di vmx_vept_fault per
 * pagina aggregati. vmx_vcpu.nested +696, vmx_nested.vept_root +17720. DMAP 0xfffff80000000000. */
int go; int64_t t0; int cnt[uint64_t];
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:exit:entry { self->rip = *(uint64_t *)((uintptr_t)arg2 + 8); }
vmm:vmx:nested:eptviol /go/ { this->pg = arg3 & ~0xfffULL; cnt[this->pg]++; self->n = cnt[this->pg]; }
vmm:vmx:nested:eptviol /go && (self->n == 5 || self->n == 50 || self->n == 500 || self->n == 5000)/ {
	this->ne = *(uintptr_t *)(arg0 + 696); this->root = *(uint64_t *)(this->ne + 17720); this->g = arg3;
	this->e3 = *(uint64_t *)(this->root + 8*((this->g>>39)&511));
	this->e2 = (this->e3 & 7) ? *(uint64_t *)(0xfffff80000000000ULL + (this->e3 & 0x000ffffffffff000ULL) + 8*((this->g>>30)&511)) : 0;
	this->e1 = (this->e2 & 7) ? *(uint64_t *)(0xfffff80000000000ULL + (this->e2 & 0x000ffffffffff000ULL) + 8*((this->g>>21)&511)) : 0;
	this->e0 = (this->e1 & 7) ? *(uint64_t *)(0xfffff80000000000ULL + (this->e1 & 0x000ffffffffff000ULL) + 8*((this->g>>12)&511)) : 0;
	printf("%10d t%d RIPETUTA x%d gpa=%#lx rip=%#lx qual=%#lx eptp %s | shadow L4=%#lx L3=%#lx L2=%#lx L1=%#lx\n",
	    (timestamp-t0)/1000, tid, self->n, (long)arg3, (long)self->rip, (long)arg4, arg1==arg2?"ok":"DIVERSO",
	    (long)this->e3, (long)this->e2, (long)this->e1, (long)this->e0);
}
fbt:vmm-restore:vmx_vept_fault:entry /go/ { self->vg = arg1 & ~0xfffULL; }
fbt:vmm-restore:vmx_vept_fault:return /go/ { @es[(long)self->vg, (int)arg1] = count(); }
tick-5s /go/ { printf("--- %d s: pagine con piu' fault (gpa, esito: n)\n", (timestamp-t0)/1000000000);
	trunc(@es, 8); printa("    gpa=%#lx esito=%d: %@d\n", @es); }
