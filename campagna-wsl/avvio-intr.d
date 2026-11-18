#!/usr/sbin/dtrace -qs
/*
 * Parere Opus 007 §6 punti 1-2: nello stesso avvio che muore
 *  - chi scrive la configurazione fisica (stack + ustack), bus 3/4 sempre,
 *    tutti i bus fra 10 e 40 s;
 *  - le VMCALL della radice (uscita 18 da L2, riflessa): RCX/RDX/R8 all'uscita,
 *    RAX al rientro in L2 dello stesso vCPU, durata; singole se codice >= 0x40
 *    o durata > 50 ms; quelle che non tornano entro 50 ms segnalate dal tick;
 *  - ogni 10 ms (10-40 s): ingressi in L2 e uscite dall'L1 per vCPU, accessi
 *    AHCI, pptintr; per i vCPU senza ingressi in L2, RIP e motivo dell'ultima
 *    uscita dall'L1.
 * Offset (DWARF di cc97efda513e): vmx_vcpu +104 vmxctx (rdx +120, rcx +128,
 * r8 +136, rax +152), +696 nested (in_l2 a +1), +704 vcpuid; vm_exit +8 rip,
 * +20 motivo. Solo kernel, nessun -p.
 */
#pragma D option aggrate=100hz
#pragma D option switchrate=100hz
#pragma D option dynvarsize=64m
#pragma D option bufsize=128m
#pragma D option ustackframes=40
BEGIN { t0 = timestamp; }
fbt:vmm-restore:vmx_run:entry { self->vc = arg0; }
fbt:vmm-restore:vmx_run:return { self->vc = 0; }

fbt:kernel:pci_cfgregwrite:entry
/arg1 == 3 || arg1 == 4 || (timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000)/
{
	printf("%6d cfgw %d/%d/%d reg=0x%x val=0x%x %s[%d] tid=%d\n", (timestamp - t0) / 1000000,
	    arg1, arg2, arg3, arg4, arg5, execname, pid, tid);
	stack(14); ustack(40);
}
fbt:vmm-restore:ppt_setup_msi:entry
{ printf("%6d ppt_setup_msi %d/%d/%d addr=%x data=%x n=%d tid=%d\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4, arg5, arg6, tid); }
fbt:vmm-restore:ppt_setup_msix:entry
{ printf("%6d ppt_setup_msix %d/%d/%d idx=%d\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4); }
fbt:vmm-restore:ppt_map_mmio:entry
{ printf("%6d ppt_map %d/%d/%d gpa=%x len=%x\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4, arg5); }
fbt:vmm-restore:ppt_unmap_mmio:entry
{ printf("%6d ppt_unmap %d/%d/%d gpa=%x\n", (timestamp - t0) / 1000000, arg1, arg2, arg3, arg4); }
fbt:vmm-restore:ppt_reset_device:entry, fbt:vmm-restore:ppt_sbr_device:entry, fbt:vmm-restore:ppt_disable_msix:entry, fbt:vmm-restore:ppt_teardown_msi:entry
{ printf("%6d %s\n", (timestamp - t0) / 1000000, probefunc); }
fbt:vmm-restore:pptintr:entry { npi++; }
fbt:vmm-restore:vmx_vept_fault:entry { self->p = arg3; }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3 && (*(uint64_t *)self->p >> 12) == $1/ { nahci++; }

/* uscite: L1 (in_l2 == 0) o VMCALL dell'L2 */
vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0/
{
	this->in2 = *(uint8_t *)(*(uintptr_t *)(self->vc + 696) + 1);
	this->mot = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
}
vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0 && this->in2 == 0/
{ l1x[arg1]++; l1rip[arg1] = *(uint64_t *)((uintptr_t)arg2 + 8); l1mot[arg1] = this->mot; }
vmm:vmx:exit:entry
/self->vc && *(uintptr_t *)(self->vc + 696) != 0 && this->in2 != 0 && this->mot == 18/
{
	self->hc = timestamp;
	self->rcx = *(uint64_t *)(self->vc + 128);
	self->rdx = *(uint64_t *)(self->vc + 120);
	self->r8 = *(uint64_t *)(self->vc + 136);
	hcs[arg1] = timestamp; hcc[arg1] = self->rcx; hcw[arg1] = 0;
	@hc[self->rcx & 0xffff] = count();
}

vmm:vmx:nested:enter_l2
{ this->v = *(int *)((uintptr_t)arg0 + 704); l2e[this->v]++; }
vmm:vmx:nested:enter_l2
/self->hc/
{
	this->d = timestamp - self->hc;
	this->rax = *(uint64_t *)((uintptr_t)arg0 + 152);
	this->code = self->rcx & 0xffff;
	@hcd[this->code] = quantize(this->d / 1000);
	hcs[this->v] = 0;
}
vmm:vmx:nested:enter_l2
/self->hc && (this->code >= 0x40 || this->d > 50000000)/
{
	printf("%6d hc v%d code=0x%x fast=%d rep=%d rdx=%x r8=%x -> rax=%x st=0x%x %d us\n",
	    (timestamp - t0) / 1000000, this->v, this->code, (self->rcx >> 16) & 1,
	    (self->rcx >> 32) & 0xfff, self->rdx, self->r8, this->rax, this->rax & 0xffff,
	    this->d / 1000);
}
vmm:vmx:nested:enter_l2 /self->hc/ { self->hc = 0; }

tick-100ms /timestamp - t0 < 10000000000 || timestamp - t0 > 40000000000/
{ printf("%6d tick ahci=%d pptintr=%d\n", (timestamp - t0) / 1000000, nahci, npi); nahci = 0; npi = 0; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000/
{
	printf("%6d t ahci=%d pi=%d L2 %d %d %d %d %d %d %d %d | L1 %d %d %d %d %d %d %d %d\n",
	    (timestamp - t0) / 1000000, nahci, npi,
	    l2e[0], l2e[1], l2e[2], l2e[3], l2e[4], l2e[5], l2e[6], l2e[7],
	    l1x[0], l1x[1], l1x[2], l1x[3], l1x[4], l1x[5], l1x[6], l1x[7]);
	nahci = 0; npi = 0;
}
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[0] == 0/
{ printf("       v0 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[0], l1mot[0]); }
tick-10ms /hcs[0] && timestamp - hcs[0] > 50000000 && hcw[0] == 0/
{ printf("%6d hc v0 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[0]) / 1000000, hcc[0]); hcw[0] = 1; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[1] == 0/
{ printf("       v1 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[1], l1mot[1]); }
tick-10ms /hcs[1] && timestamp - hcs[1] > 50000000 && hcw[1] == 0/
{ printf("%6d hc v1 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[1]) / 1000000, hcc[1]); hcw[1] = 1; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[2] == 0/
{ printf("       v2 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[2], l1mot[2]); }
tick-10ms /hcs[2] && timestamp - hcs[2] > 50000000 && hcw[2] == 0/
{ printf("%6d hc v2 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[2]) / 1000000, hcc[2]); hcw[2] = 1; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[3] == 0/
{ printf("       v3 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[3], l1mot[3]); }
tick-10ms /hcs[3] && timestamp - hcs[3] > 50000000 && hcw[3] == 0/
{ printf("%6d hc v3 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[3]) / 1000000, hcc[3]); hcw[3] = 1; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[4] == 0/
{ printf("       v4 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[4], l1mot[4]); }
tick-10ms /hcs[4] && timestamp - hcs[4] > 50000000 && hcw[4] == 0/
{ printf("%6d hc v4 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[4]) / 1000000, hcc[4]); hcw[4] = 1; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[5] == 0/
{ printf("       v5 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[5], l1mot[5]); }
tick-10ms /hcs[5] && timestamp - hcs[5] > 50000000 && hcw[5] == 0/
{ printf("%6d hc v5 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[5]) / 1000000, hcc[5]); hcw[5] = 1; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[6] == 0/
{ printf("       v6 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[6], l1mot[6]); }
tick-10ms /hcs[6] && timestamp - hcs[6] > 50000000 && hcw[6] == 0/
{ printf("%6d hc v6 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[6]) / 1000000, hcc[6]); hcw[6] = 1; }
tick-10ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000 && l2e[7] == 0/
{ printf("       v7 fermo: ultima uscita L1 rip=%x motivo=%d\n", l1rip[7], l1mot[7]); }
tick-10ms /hcs[7] && timestamp - hcs[7] > 50000000 && hcw[7] == 0/
{ printf("%6d hc v7 NON TORNA da %d ms: rcx=%x\n", (timestamp - t0) / 1000000, (timestamp - hcs[7]) / 1000000, hcc[7]); hcw[7] = 1; }
tick-10ms
{
	l2e[0] = 0; l2e[1] = 0; l2e[2] = 0; l2e[3] = 0; l2e[4] = 0; l2e[5] = 0; l2e[6] = 0; l2e[7] = 0;
	l1x[0] = 0; l1x[1] = 0; l1x[2] = 0; l1x[3] = 0; l1x[4] = 0; l1x[5] = 0; l1x[6] = 0; l1x[7] = 0;
}
tick-1s /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000/
{ printf("%6d VMCALL per codice nell'ultimo secondo:\n", (timestamp - t0) / 1000000); printa("    0x%x %@d\n", @hc); trunc(@hc); }

/*
 * Aggiunta (avvio-intr.d): flussi d'interrupt ogni 100 ms fra 10 e 40 s.
 *  msi  = lapic_intr_msi verso l'L1: (APIC di destinazione, vettore)
 *  l1v  = vlapic_set_intr_ready dell'L1, per vettore
 *  l2v  = interrupt/eventi iniettati nell'L2 dal VMCS12 (tipo<<8 | vettore)
 *  ahv  = accessi emulati alla pagina AHCI per vCPU
 */
fbt:vmm-restore:lapic_intr_msi:entry /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000/
{ @msi[(arg1 >> 12) & 0xff, arg2 & 0xff] = count(); }
fbt:vmm-restore:vlapic_set_intr_ready:entry /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000/
{ @l1v[arg1] = count(); }
vmm:vmx:nested:compose /(arg1 & 0x80000000) && timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000/
{ @l2v[arg1 & 0x7ff] = count(); }
fbt:vmm-restore:vmx_vept_fault:entry { self->vv = *(int *)((uintptr_t)arg0 + 704); }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3 && (*(uint64_t *)self->p >> 12) == $1 && timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000/
{ @ahv[self->vv] = count(); }
tick-100ms /timestamp - t0 > 10000000000 && timestamp - t0 < 40000000000/
{
	printf("%6d I msi", (timestamp - t0) / 1000000); printa(" %x/%x:%@d", @msi);
	printf(" | l1v"); printa(" %x:%@d", @l1v);
	printf(" | l2v"); printa(" %x:%@d", @l2v);
	printf(" | ahv"); printa(" v%d:%@d", @ahv); printf("\n");
	trunc(@msi); trunc(@l1v); trunc(@l2v); trunc(@ahv);
}
tick-150s { printa("durata VMCALL (us) codice 0x%x %@d\n", @hcd); exit(0); }
fbt:vmm-restore:vmx_vept_fault:return { self->p = 0; }
