#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option aggsize=8m
#pragma D option switchrate=5hz
/* Claude 19/10/2026 — Astra #4: l1_tsc_offset (base TSC L0->L1) a ogni
 * nested_compose_vmcs02. Se costante su tutte le entrate L2 -> base stabile.
 * vmx_vcpu.nested +0x2b8; vmx_nested.l1_tsc_offset +0x4600. */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
fbt:vmm-restore:nested_compose_vmcs02:entry /go/
{
	this->n = *(uintptr_t *)(arg0 + 0x2b8);
	this->off = this->n ? *(uint64_t *)(this->n + 0x4600) : 0;
	@byoff[this->off] = count();
}
tick-5s /go/
{
	printf("=== %ds  l1_tsc_offset distinti (valore : n.compose):\n", (timestamp - t0)/1000000000);
	printa("  %#x : %@d\n", @byoff);
}
