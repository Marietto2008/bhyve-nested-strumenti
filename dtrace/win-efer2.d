#pragma D option quiet
#pragma D option switchrate=4hz
/* Claude 20/10/2026 parere #19: EFER del VMCS02 per VTL (eptp12), nel tempo.
 * efer2(vcpuid, eptp12, efer02). Prima: sysctl hw.vmm.vmx.diag_efer=1 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:nested:efer2
{
	@per[arg1, (int)(arg2 & 1)] = count();   /* eptp12, SCE */
	@ult[arg1, (int)(arg2 & 1)] = max((timestamp - t0)/1000000);
}
tick-10s /go/
{
	printf("=== %ds: EFER del VMCS02 per VTL ===\n", (timestamp - t0)/1000000000);
	printa("  VTL %#lx SCE=%d : %@d ingressi\n", @per);
	printa("  VTL %#lx SCE=%d ultimo a %@d ms\n", @ult);
}
