#!/usr/sbin/dtrace -qs
/*
 * Parere Opus 006 §3: linea temporale al ms dell'avvio del dispositivo passato.
 * Eventi stampati subito (ms dall'inizio): scritture fisiche di configurazione
 * sui bus 3/4 (pci_cfgregwrite), chiamate ppt_* del modulo, ioctl di bhyve
 * diverse da VM_RUN; ogni 100 ms gli accessi emulati alla pagina AHCI
 * (c200a000 nella configurazione audio RX 6600). Solo kernel, nessun -p.
 */
#pragma D option aggrate=50hz
#pragma D option switchrate=50hz
#pragma D option dynvarsize=16m
BEGIN { t0 = timestamp; }
fbt:kernel:pci_cfgregwrite:entry /arg1 == 3 || arg1 == 4/
{ printf("%6d cfgw %d/%d/%d reg=0x%x val=0x%x\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4, arg5); }
fbt:vmm-restore:ppt_setup_msi:entry
{ printf("%6d ppt_setup_msi %d/%d/%d addr=%x data=%x n=%d\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4, arg5, arg6); }
fbt:vmm-restore:ppt_setup_msix:entry
{ printf("%6d ppt_setup_msix %d/%d/%d idx=%d\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4); }
fbt:vmm-restore:ppt_map_mmio:entry
{ printf("%6d ppt_map %d/%d/%d gpa=%x len=%x\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4, arg5); }
fbt:vmm-restore:ppt_unmap_mmio:entry
{ printf("%6d ppt_unmap %d/%d/%d gpa=%x\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4); }
fbt:vmm-restore:ppt_reset_device:entry, fbt:vmm-restore:ppt_sbr_device:entry, fbt:vmm-restore:ppt_disable_msix:entry, fbt:vmm-restore:ppt_teardown_msi:entry
{ printf("%6d %s\n", (timestamp - t0) / 1000000, probefunc); }
fbt:vmm-restore:pptintr:entry { @ppt = count(); }
fbt:vmm-restore:vmx_vept_fault:entry { self->p = arg3; }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3 && (*(uint64_t *)self->p >> 12) == 0xc200a/ { @ahci = count(); }
fbt:vmm-restore:vmx_vept_fault:return { self->p = 0; }
tick-100ms
{
	printf("%6d tick", (timestamp - t0) / 1000000);
	printa(" ahci=%@d", @ahci); printa(" pptintr=%@d", @ppt); printf("\n");
	trunc(@ahci); trunc(@ppt);
}
tick-150s { exit(0); }
