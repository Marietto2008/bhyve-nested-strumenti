#pragma D option quiet
fbt:vmm-restore:vmx_vept_invept:entry { @who[stack(4)] = count(); }
fbt:vmm-restore:nested_invept:entry { @inv = count(); }
fbt:vmm-restore:vmx_vept_prepare:entry { self->n = *(uintptr_t *)(arg0 + 696); self->old = *(uint64_t *)(self->n + 17728); }
fbt:vmm-restore:vmx_vept_prepare:return /self->n/ { this->new = *(uint64_t *)(self->n + 17728);
	@pr[(long)self->old, (long)this->new] = count(); self->n = 0; }
tick-8s { printa("azzeramento da:%k: %@d\n\n", @who); printa("INVEPT dell'L1: %@d\n", @inv);
	printa("prepare eptp12 %#lx -> %#lx: %@d\n", @pr); exit(0); }
