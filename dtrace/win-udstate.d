#pragma D option quiet
#pragma D option switchrate=10hz
/*
 * Claude 20/10/2026 -- parere #18: stato al #UD in L2. Sonde del modulo:
 *   ud_a(vcpuid, cr3, rip, rsp, cr4, efer)
 *   ud_b(vcpuid, reason|cs<<16|idtvec<<32, exit_intr_info, exit_qual, gla, gpa)
 *   ud_c(vcpuid, excbitmap02, excbitmap12, entry_intr_info, exitintinfo, eptp12)
 * Prima: sysctl hw.vmm.vmx.diag_ud=1
 */
int go; int64_t t0; int done;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:nested:ud_a /done < 8/
{
	printf("UDA cr3=%#lx rip=%#lx rsp=%#lx cr4=%#lx efer=%#lx\n", arg1, arg2, arg3, arg4, arg5);
	self->rip = arg2;
}
vmm:vmx:nested:ud_b /done < 8/
{
	printf("UDB reason=%d cs=%#x idtvec=%#x exit_intr=%#x qual=%#lx gla=%#lx gpa=%#lx\n",
	    (int)(arg1 & 0xffff), (int)((arg1 >> 16) & 0xffff), (int)(arg1 >> 32),
	    (int)arg2, arg3, arg4, arg5);
}
vmm:vmx:nested:ud_c /done < 8/
{
	printf("UDC excbm02=%#lx excbm12=%#lx entry_intr=%#x exitintinfo=%#lx eptp12=%#lx\n",
	    arg1, arg2, (int)arg3, arg4, arg5);
	done++;
}
