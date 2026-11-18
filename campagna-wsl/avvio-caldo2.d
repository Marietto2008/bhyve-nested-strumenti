#!/usr/sbin/dtrace -qs
/*
 * Abilitazione a caldo sotto nesting, versione corretta col parere di Astra
 * sul rapporto 008 (§3-4). Si avvia ~5 s PRIMA di abilitare il dispositivo.
 *  - innesco: scrittura FISICA dell'MSI Control (0xa2) del 3/0/1 col bit 0
 *    acceso (abilitazione reale; argomenti tutti nei registri);
 *  - solo aggregazioni a intervalli fissi (b = 10 ms dall'inizio), stampate
 *    UNA volta alla fine (2 s dopo l'innesco): niente printa/trunc periodici;
 *  - vm_exit alla sonda exit:entry: u.vmx (DWARF di cc97efda: status +16,
 *    exit_reason +20, exit_qualification +24). I/O: porta = qual>>16,
 *    in = bit 3, byte = (qual & 7) + 1. Bit 31 del motivo = ingresso fallito;
 *  - esiti di vmx_vept_fault per pagina L2 in 0xc2000000-0xc20fffff;
 *  - eventi composti nel VMCS02: valido, tipo (bit 8-10), vettore;
 *  - enter_l2 = TENTATIVI d'ingresso (la sonda precede VMLAUNCH/VMRESUME).
 * Offset vmx_vcpu: +696 nested (in_l2 a +1), +704 vcpuid.
 */
#pragma D option aggsize=256m
#pragma D option dynvarsize=64m
#pragma D option bufsize=64m
BEGIN { t0 = timestamp; ttrig = 0; }
fbt:vmm-restore:vmx_run:entry { self->vc = arg0; }
fbt:vmm-restore:vmx_run:return { self->vc = 0; }

fbt:kernel:pci_cfgregwrite:entry /arg1 == 3 && arg2 == 0 && arg3 == 1/
{ @cfg[(timestamp - t0) / 1000000, arg4, arg5] = count(); }
fbt:kernel:pci_cfgregwrite:entry /arg1 == 3 && arg2 == 0 && arg3 == 1 && arg4 == 0xa2 && (arg5 & 1) && ttrig == 0/
{ ttrig = timestamp; }
fbt:vmm-restore:ppt_setup_msi:entry /arg1 == 3 && arg2 == 0 && arg3 == 1/
{ @msiset[(timestamp - t0) / 1000000, arg4, arg5] = count(); }
fbt:vmm-restore:ppt_map_mmio:entry, fbt:vmm-restore:ppt_unmap_mmio:entry
{ @bar[(timestamp - t0) / 1000000, probefunc, arg4] = count(); }
fbt:vmm-restore:pptintr:entry { @ppt[(timestamp - t0) / 10000000] = count(); }

vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0/
{
	this->b = (timestamp - t0) / 10000000;
	this->in2 = *(uint8_t *)(*(uintptr_t *)(self->vc + 696) + 1);
	this->er = *(uint32_t *)((uintptr_t)arg2 + 20);
	this->q = *(uint64_t *)((uintptr_t)arg2 + 24);
	@mot[this->b, arg1, this->in2, this->er & 0xffff, this->er >> 31] = count();
}
vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0 && (this->er & 0xffff) == 30/
{ @io[this->b, arg1, this->in2, (this->q >> 16) & 0xffff, (this->q >> 3) & 1, (this->q & 7) + 1] = count(); }
vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0 && arg1 == 0/
{ @rip0[(timestamp - t0) / 100000000, this->in2, this->er & 0xffff, *(uint64_t *)((uintptr_t)arg2 + 8)] = count(); }

vmm:vmx:nested:enter_l2 { @l2try[(timestamp - t0) / 10000000, *(int *)((uintptr_t)arg0 + 704)] = count(); }
vmm:vmx:nested:compose /arg1 & 0x80000000/
{ @inj[(timestamp - t0) / 10000000, *(int *)((uintptr_t)arg0 + 704), (arg1 >> 8) & 7, arg1 & 0xff] = count(); }
fbt:vmm-restore:lapic_intr_msi:entry
{ @msi[(timestamp - t0) / 10000000, (arg1 >> 12) & 0xff, arg2 & 0xff] = count(); }

fbt:vmm-restore:vmx_vept_fault:entry /arg1 >= 0xc2000000 && arg1 < 0xc2100000/
{ self->vp = arg1; self->vv = *(int *)((uintptr_t)arg0 + 704); }
fbt:vmm-restore:vmx_vept_fault:return /self->vp/
{ @vf[(timestamp - t0) / 10000000, self->vv, self->vp >> 12, arg1] = count(); self->vp = 0; }

tick-10ms /ttrig != 0 && timestamp - ttrig > 2000000000/
{
	printf("t0 %d ttrig %d ms\n", t0, (ttrig - t0) / 1000000);
	printa("cfg ms=%d reg=0x%x val=0x%x %@d\n", @cfg);
	printa("msiset ms=%d addr=%x data=%x %@d\n", @msiset);
	printa("bar ms=%d %s gpa=%x %@d\n", @bar);
	printa("ppt b=%d %@d\n", @ppt);
	printa("mot b=%d v%d l2=%d motivo=%d fallito=%d %@d\n", @mot);
	printa("io b=%d v%d l2=%d porta=0x%x in=%d byte=%d %@d\n", @io);
	printa("rip0 b100=%d l2=%d motivo=%d rip=%x %@d\n", @rip0);
	printa("l2try b=%d v%d %@d\n", @l2try);
	printa("inj b=%d v%d tipo=%d vett=0x%x %@d\n", @inj);
	printa("msi b=%d dest=%d vett=0x%x %@d\n", @msi);
	printa("vf b=%d v%d pagina=%x esito=%d %@d\n", @vf);
	exit(0);
}
tick-120s { printf("innesco mai visto\n"); exit(0); }
