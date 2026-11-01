#pragma D option quiet
vmm:vmx:exit:entry {
	this->vx = (struct vmexit *)arg2;
	@r[arg1, *(uint32_t *)(arg2 + 20)] = count();
	@rip[arg1, *(uint64_t *)(arg2 + 8)] = count();
}
vmm:vmx:nested:reflect { @refl[arg1] = count(); }
tick-5s {
	printa("vcpu%d reason %d: %@d\n", @r);
	trunc(@rip, 12); printa("vcpu%d rip %#lx: %@d\n", @rip);
	printa("reflect %d: %@d\n", @refl);
	exit(0);
}
