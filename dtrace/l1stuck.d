#pragma D option quiet
vmm:vmx:exit:entry { @ex[arg1, *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff] = count(); @rip[arg1, *(uint64_t *)((uintptr_t)arg2 + 8)] = count(); }
fbt:vmm-restore:vlapic_icrlo_write_handler:entry { @ipi = count(); }
fbt:vmm-restore:vm_handle_ipi:entry { @hipi[arg1] = count(); }
fbt:vmm-restore:vlapic_set_intr_ready:entry { @v[arg1, arg0] = count(); }
fbt:vmm-restore:lapic_wrmsr:entry /arg1 == 0x830 || arg1 == 0x83e/ { @icr[arg1, arg2] = count(); }
fbt:vmm-restore:vlapic_callout_handler:entry { @tmr = count(); }
tick-5s { printa("cpu%d uscita motivo %d: %@d\n", @ex); trunc(@rip,8); printa("cpu%d rip %#lx: %@d\n", @rip);
  printa("ICR (IPI) scritti: %@d\n", @ipi); printa("vm_handle_ipi dest %d: %@d\n", @hipi);
  printa("x2APIC ICR msr=%#x val=%#x: %@d\n", @icr); printa("timer L1 scatta: %@d\n", @tmr);
  printa("vettore %#x -> vlapic %p: %@d\n", @v); exit(0); }
