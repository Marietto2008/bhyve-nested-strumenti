#pragma D option quiet
#pragma D option switchrate=4hz
/* Claude 20/10 parere #20: EFER del VMCS02 per (VMCS12, VTL). efer2(vcpuid, eptp12, efer02, vmcs12). */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:nested:efer2
{
	@per[arg3, arg1, (int)(arg2 & 1)] = count();   /* vmcs12, eptp12, SCE */
	@ult[arg3, (int)(arg2 & 1)] = max((timestamp - t0)/1000000);
}
tick-10s /go/
{
	printf("=== %ds: EFER per (VMCS12, VTL) ===\n", (timestamp - t0)/1000000000);
	printa("  vmcs12=%#lx VTL=%#lx SCE=%d : %@d\n", @per);
	printa("  vmcs12=%#lx SCE=%d ultimo a %@d ms\n", @ult);
}
