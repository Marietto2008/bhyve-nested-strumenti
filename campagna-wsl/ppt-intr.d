#!/usr/sbin/dtrace -qs
/* interrupt dei dispositivi in passthrough consegnati alla VM (kernel, nessun -p) */
fbt:vmm-restore:pptintr:entry { self->in = 1; @n["pptintr"] = count(); }
fbt:vmm-restore:lapic_intr_msi:entry /self->in/ { @m[arg1, arg2] = count(); }
fbt:vmm-restore:pptintr:return { self->in = 0; }
fbt:vmm-restore:ppt_setup_msix:entry { printf("setup_msix %d/%d/%d idx=%d addr=%x data=%x ctl=%x\n", arg1, arg2, arg3, arg4, arg5, arg6, arg7); }
fbt:vmm-restore:ppt_setup_msi:entry { printf("setup_msi %d/%d/%d addr=%x data=%x nvec=%d\n", arg1, arg2, arg3, arg4, arg5, arg6); }
tick-15s { printa("%s: %@d\n", @n); printa("  msi addr=%x data=%x: %@d\n", @m); exit(0); }
