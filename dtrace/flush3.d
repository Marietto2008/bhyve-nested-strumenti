#pragma D option quiet
fbt:vmm-restore:vmx_vept_invept:entry { @who[stack(4)] = count(); }
fbt:vmm-restore:vmx_vept_flush:entry { @fl[stack(4)] = count(); }
fbt:vmm-restore:vmx_vept_prepare:entry { self->n = *(uintptr_t *)(arg0 + 696); self->old = *(uint64_t *)(self->n + 17728); }
fbt:vmm-restore:vmx_vept_prepare:return /self->n/ { this->new = *(uint64_t *)(self->n + 17728);
	@pr[(long)self->old, (long)this->new] = count(); self->n = 0; }
fbt:vmm-restore:vmx_vept_fault:entry { @f = count(); }
tick-8s { printa("azzeramento da:%k: %@d\n\n", @who); printa("flush da:%k: %@d\n\n", @fl);
	printa("prepare eptp12 %#lx -> %#lx: %@d\n", @pr); printa("vept_fault: %@d\n", @f); exit(0); }
