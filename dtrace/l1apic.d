#pragma D option quiet
int seen[uintptr_t];
fbt:vmm-restore:vlapic_pending_intr:entry /!seen[arg0]/ { seen[arg0]=1; this->p=*(uintptr_t *)(arg0+24);
  printf("vlapic %p TPR=%x PPR=%x LVTt=%x init=%x cur=%x\n  ISR: %08x %08x %08x %08x %08x %08x %08x %08x\n  IRR: %08x %08x %08x %08x %08x %08x %08x %08x\n", arg0,
   *(uint32_t *)(this->p+128),*(uint32_t *)(this->p+160),*(uint32_t *)(this->p+800),*(uint32_t *)(this->p+896),*(uint32_t *)(this->p+912),
   *(uint32_t *)(this->p+256),*(uint32_t *)(this->p+272),*(uint32_t *)(this->p+288),*(uint32_t *)(this->p+304),*(uint32_t *)(this->p+320),*(uint32_t *)(this->p+336),*(uint32_t *)(this->p+352),*(uint32_t *)(this->p+368),
   *(uint32_t *)(this->p+512),*(uint32_t *)(this->p+528),*(uint32_t *)(this->p+544),*(uint32_t *)(this->p+560),*(uint32_t *)(this->p+576),*(uint32_t *)(this->p+592),*(uint32_t *)(this->p+608),*(uint32_t *)(this->p+624)); }
tick-6s { exit(0); }
