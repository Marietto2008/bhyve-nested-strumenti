#!/usr/sbin/dtrace -qs
/*
 * Abilitazione a caldo del dispositivo passato sotto nesting (riproduttore).
 * $1 = pagina AHCI (es. 0xc200a), $2 = vettore L1 dell'AHCI (es. 0xb8).
 * Fase 0 = prima dell'MSI di Hyper-V (ppt_setup_msi n=1), fase 1 = il secondo
 * dopo. Per fase: motivi d'uscita per vCPU e livello (in_l2), porte di I/O,
 * RIP piu' frequenti. Ogni 10 ms, con GLOBALI (niente printa: il consumatore
 * in ritardo falsa i tempi): AHCI, MSI 0xb8 verso l'L1, 0xb8 iniettato nell'L2,
 * ingressi in L2 per vCPU. Esce 5 s dopo l'MSI.
 */
#pragma D option dynvarsize=64m
#pragma D option bufsize=64m
#pragma D option switchrate=100hz
BEGIN { t0 = timestamp; tdev = 0; fase = 0; }
fbt:vmm-restore:vmx_run:entry { self->vc = arg0; }
fbt:vmm-restore:vmx_run:return { self->vc = 0; }
fbt:vmm-restore:ppt_setup_msi:entry /arg6 == 1 && tdev == 0/
{ tdev = timestamp; fase = 1; printf("%6d MSI DISPOSITIVO addr=%x data=%x\n", (timestamp - t0) / 1000000, arg4, arg5); }
fbt:kernel:pci_cfgregwrite:entry /arg1 == 3/
{ printf("%6d cfgw %d/%d/%d reg=0x%x val=0x%x\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4, arg5); }
fbt:vmm-restore:vmx_vept_fault:entry { self->p = arg3; }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3 && (*(uint64_t *)self->p >> 12) == $1/ { nahci++; }
fbt:vmm-restore:vmx_vept_fault:return { self->p = 0; }
fbt:vmm-restore:lapic_intr_msi:entry /(arg2 & 0xff) == $2/ { nmsi++; }
fbt:vmm-restore:lapic_intr_msi:entry /(arg2 & 0xff) == 0x71/ { ndev++; }
vmm:vmx:nested:compose /(arg1 & 0x800000ff) == (0x80000000 | $2)/ { ninj++; }
vmm:vmx:nested:enter_l2 { l2e[*(int *)((uintptr_t)arg0 + 704)]++; }

vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0 && (fase == 0 || timestamp - tdev < 1000000000)/
{
	this->in2 = *(uint8_t *)(*(uintptr_t *)(self->vc + 696) + 1);
	this->mot = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	@mot[fase, arg1, this->in2, this->mot] = count();
	@rip[fase, arg1, this->in2, *(uint64_t *)((uintptr_t)arg2 + 8)] = count();
}
vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0 && (fase == 0 || timestamp - tdev < 1000000000) && this->mot == 30/
{ @io[fase, arg1, this->in2, *(uint16_t *)((uintptr_t)arg2 + 18), (*(uint8_t *)((uintptr_t)arg2 + 16) >> 3) & 1] = count(); }

tick-10ms /tdev != 0/
{
	printf("%6d t ahci=%d msiAHCI=%d injAHCI=%d dev71=%d L2 %d %d %d %d %d %d %d %d\n",
	    (timestamp - t0) / 1000000, nahci, nmsi, ninj, ndev,
	    l2e[0], l2e[1], l2e[2], l2e[3], l2e[4], l2e[5], l2e[6], l2e[7]);
}
tick-10ms
{
	nahci = 0; nmsi = 0; ninj = 0; ndev = 0;
	l2e[0] = 0; l2e[1] = 0; l2e[2] = 0; l2e[3] = 0; l2e[4] = 0; l2e[5] = 0; l2e[6] = 0; l2e[7] = 0;
}
/* la fase 0 resta solo l'ultimo secondo prima dell'MSI */
tick-1s /tdev == 0/ { trunc(@mot); trunc(@rip); trunc(@io); }
tick-10ms /tdev != 0 && timestamp - tdev > 5000000000/
{
	trunc(@rip, 120);
	printa("mot fase=%d v%d l2=%d motivo=%d %@d\n", @mot);
	printa("io  fase=%d v%d l2=%d porta=0x%x in=%d %@d\n", @io);
	printa("rip fase=%d v%d l2=%d rip=%x %@d\n", @rip);
	exit(0);
}
