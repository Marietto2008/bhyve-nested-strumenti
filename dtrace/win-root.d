#pragma D option quiet
#pragma D option switchrate=10hz
/* vept_root e vept_eptp12 a ogni fault + confronto con l'eptp12 del VMCS12 corrente.
 * vmx_vcpu.nested +696; vmx_nested: vept_root +17720, vept_eptp12 +17728.
 * Conta anche prepare/flush e se la radice cambia puntatore. */
uint64_t lastroot[int];
fbt:vmm-restore:vmx_vept_fault:entry {
	this->n = *(uintptr_t *)(arg0 + 696);
	this->root = *(uint64_t *)(this->n + 17720);
	this->e12 = *(uint64_t *)(this->n + 17728);
	@byroot[this->root, this->e12] = count();
	@acc[arg2 & 7] = count();
	if (lastroot[tid] != 0 && lastroot[tid] != this->root) @rootchg = count();
	lastroot[tid] = this->root;
}
fbt:vmm-restore:vmx_vept_prepare:entry { @prep = count(); }
fbt:vmm-restore:vmx_vept_invept:entry { @reb = count(); }
fbt:vmm-restore:vept_install:entry { @ins = count(); }
tick-5s {
	printa("  root=%#lx eptp12=%#lx: %@d fault\n", @byroot);
	printa("  accesso (R=1 W=2 X=4) %d: %@d\n", @acc);
	printa("  cambi di radice: %@d\n", @rootchg);
	printa("  vmx_vept_prepare: %@d\n", @prep);
	printa("  rebuild radice (vmx_vept_invept): %@d\n", @reb);
	printa("  vept_install: %@d\n", @ins);
	exit(0);
}
