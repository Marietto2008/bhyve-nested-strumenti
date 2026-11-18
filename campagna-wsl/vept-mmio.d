#!/usr/sbin/dtrace -qs
/* esiti VEPT_MMIO (3) di vmx_vept_fault: L2-GPA e L1-GPA (kernel, nessun -p) */
fbt:vmm-restore:vmx_vept_fault:entry
{ self->l2 = arg1; self->q = arg2; self->p = arg3; }
fbt:vmm-restore:vmx_vept_fault:return
/self->p && arg1 == 3/
{ printf("%Y MMIO l2gpa=%x l1gpa=%x qual=%x\n", walltimestamp, self->l2, *(uint64_t *)self->p, self->q); }
fbt:vmm-restore:vmx_vept_fault:return
{ @esito[arg1] = count(); self->p = 0; }
END
{ printa("esito %d: %@d\n", @esito); }
