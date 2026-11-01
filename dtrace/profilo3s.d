#pragma D option quiet
vmm:vmx:exit:entry { @r[arg1, *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff] = count(); @rip[arg1, *(uint64_t *)((uintptr_t)arg2 + 8)] = count(); }
fbt:vmm-restore:nested_l2_exit:entry { @l2 = count(); }
vmm:vmx:nested:compose { @c = count(); }
fbt:vmm-restore:vlapic_set_intr_ready:entry { @v[arg1] = count(); }
tick-3s { printa("cpu%d uscite motivo %d: %@d\n", @r); trunc(@rip, 6); printa("cpu%d rip %#lx: %@d\n", @rip); printa("uscite dalla root (L2): %@d\n", @l2); printa("ingressi nella root: %@d\n", @c); printa("vettore %#x: %@d\n", @v); exit(0); }
