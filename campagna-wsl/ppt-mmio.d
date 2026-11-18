#!/usr/sbin/dtrace -qs
/* mappature MMIO dei dispositivi in passthrough (kernel, nessun -p) */
fbt:vmm-restore:ppt_map_mmio:entry
{ self->a = 1; printf("%Y map %d/%d/%d gpa=%x len=%x hpa=%x", walltimestamp, arg1, arg2, arg3, arg4, arg5, arg6); }
fbt:vmm-restore:ppt_map_mmio:return
/self->a/
{ printf(" -> %d\n", arg1); self->a = 0; }
fbt:vmm-restore:ppt_unmap_mmio:entry
{ printf("%Y unmap %d/%d/%d gpa=%x len=%x\n", walltimestamp, arg1, arg2, arg3, arg4, arg5); }
