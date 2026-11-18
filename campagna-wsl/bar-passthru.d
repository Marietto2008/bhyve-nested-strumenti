#!/usr/sbin/dtrace -qs
/* BAR del dispositivo passato: mappature di bhyve, esiti VEPT_MMIO e vm_fault
 * sulle pagine 0xc2000000-0xc2ffffff (kernel, nessun -p) */
fbt:vmm-restore:ppt_map_mmio:entry
{ self->m = 1; printf("%Y map %d/%d/%d gpa=%x len=%x hpa=%x", walltimestamp, arg1, arg2, arg3, arg4, arg5, arg6); }
fbt:vmm-restore:ppt_map_mmio:return /self->m/ { printf(" -> %d\n", arg1); self->m = 0; }
fbt:vmm-restore:ppt_unmap_mmio:entry
{ printf("%Y unmap %d/%d/%d gpa=%x len=%x\n", walltimestamp, arg1, arg2, arg3, arg4, arg5); }
fbt:kernel:vm_fault:entry /execname == "bhyve" && arg1 >= 0xc2000000 && arg1 < 0xc3000000/
{ self->vf = arg1; self->ft = arg2; }
fbt:kernel:vm_fault:return /self->vf/
{ @vf[self->vf, self->ft, arg1] = count(); self->vf = 0; }
fbt:vmm-restore:vmx_vept_fault:entry { self->l2 = arg1; self->q = arg2; self->p = arg3; }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3 && *(uint64_t *)self->p >= 0xc2000000 && *(uint64_t *)self->p < 0xc200a000/
{ @em[*(uint64_t *)self->p, self->q] = count(); }
fbt:vmm-restore:vmx_vept_fault:return { self->p = 0; }
tick-1s
{
	printf("--- %Y\n", walltimestamp);
	printa("    vm_fault gpa=%x tipo=%d -> %d: %@d\n", @vf);
	printa("    emulato gpa=%x qual=%x: %@d\n", @em);
	trunc(@vf); trunc(@em);
}
