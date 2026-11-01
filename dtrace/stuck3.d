#pragma D option quiet
vmm:vmx:exit:entry /(*(uint32_t *)(arg2 + 20)) == 30/ {
	this->q = *(uint64_t *)(arg2 + 24);
	this->n = *(uintptr_t *)(arg0 + 696);
	@io[arg1, (long)(this->q >> 16), (long)(this->q & 0xf)] = count();
	@l2[this->n ? *(uint8_t *)(this->n + 1) : 255] = count();
	@rax[(long)*(uint64_t *)(arg0 + 152) & 0xffff] = count();
}
tick-3s {
	printa("vcpu%d port %#lx qual-low %#lx: %@d\n", @io);
	printa("in_l2=%d: %@d\n", @l2);
	trunc(@rax, 10); printa("rax %#lx: %@d\n", @rax);
	exit(0);
}
