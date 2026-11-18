#!/usr/sbin/dtrace -qs
/*
 * Crollo del disco a 10 ms (parere Opus 005 §3.2): pagine MMIO emulate
 * (VEPT_MMIO) con lettura/scrittura, MSI iniettati per origine e dato,
 * interrupt dei dispositivi passati. Solo kernel, nessun -p. Dura 100 s.
 */
#pragma D option dynvarsize=16m
#pragma D option bufsize=64m
BEGIN { t0 = timestamp; }
fbt:vmm-restore:pptintr:entry { self->ppt = 1; @ppt = count(); }
fbt:vmm-restore:pptintr:return { self->ppt = 0; }
fbt:vmm-restore:lapic_intr_msi:entry /!self->ppt/ { @msi[arg2 & 0xff] = count(); }
fbt:vmm-restore:vmx_vept_fault:entry { self->p = arg3; self->q = arg2; }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3/
{ @mm[*(uint64_t *)self->p >> 12, (self->q & 2) ? "W" : "R"] = count(); }
fbt:vmm-restore:vmx_vept_fault:return { self->p = 0; }
tick-10ms
{
	printf("@%d", (timestamp - t0) / 1000000);
	printa(" ppt=%@d", @ppt);
	printa(" msi%x=%@d", @msi);
	trunc(@mm, 3); printa(" %x%s=%@d", @mm);
	printf("\n");
	trunc(@ppt); trunc(@msi); trunc(@mm);
}
tick-100s { exit(0); }
