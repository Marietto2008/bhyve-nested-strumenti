#!/usr/sbin/dtrace -qs
/* programmazione MSI/MSI-X dei dispositivi in passthrough e interrupt (kernel, nessun -p) */
fbt:vmm-restore:ppt_setup_msix:entry { printf("%Y setup_msix %d/%d/%d idx=%d addr=%x data=%x ctl=%x\n", walltimestamp, arg1, arg2, arg3, arg4, arg5, arg6, arg7); }
fbt:vmm-restore:ppt_setup_msix:return { printf("   -> %d\n", arg1); }
fbt:vmm-restore:ppt_setup_msi:entry { printf("%Y setup_msi %d/%d/%d addr=%x data=%x nvec=%d\n", walltimestamp, arg1, arg2, arg3, arg4, arg5, arg6); }
fbt:vmm-restore:ppt_setup_msi:return { printf("   -> %d\n", arg1); }
fbt:vmm-restore:pptintr:entry { @n = count(); }
tick-10s { printf("%Y ", walltimestamp); printa("interrupt finora: %@d\n", @n); }
