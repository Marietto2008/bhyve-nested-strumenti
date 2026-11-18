#!/usr/sbin/dtrace -qs
/* Consegna dei vettori nell'APIC virtuale dell'L1: messa in attesa,
 * consegna al vCPU, EOI. Origine dal contesto (pptintr = passthrough). Solo kernel. */
#pragma D option aggrate=10hz
#pragma D option dynvarsize=16m
fbt:vmm-restore:pptintr:entry { self->ppt = 1; }
fbt:vmm-restore:pptintr:return { self->ppt = 0; }
fbt:vmm-restore:vlapic_set_intr_ready:entry /arg1 == 0x71 || arg1 == 0xb8 || arg1 == 0x81 || arg1 == 0xa1/
{ @r[self->ppt ? "pronto(ppt)" : "pronto", arg1] = count(); }
fbt:vmm-restore:vlapic_intr_accepted:entry /arg1 == 0x71 || arg1 == 0xb8 || arg1 == 0x81 || arg1 == 0xa1/
{ @r["consegnato", arg1] = count(); }
fbt:vmm-restore:vlapic_process_eoi:entry { @e = count(); }
fbt:vmm-restore:pptintr:entry { @p = count(); }
tick-1s
{
	printf("--- %Y\n", walltimestamp);
	printa("  %-12s 0x%x: %@d\n", @r); printa("  EOI totali: %@d\n", @e); printa("  pptintr: %@d\n", @p);
	trunc(@r); trunc(@e); trunc(@p);
}
tick-100s { exit(0); }
