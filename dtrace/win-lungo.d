#pragma D option quiet
#pragma D option bufpolicy=ring
#pragma D option bufsize=32m
/* Corsa lunga Windows 11 + Hyper-V: riassunto al secondo + ultimi eventi prima del reset.
 * Si ferma alla prima VM_SUSPEND dopo il primo ingresso in L2 (reset 0xCF9) o dopo 30 min. */
int go; int64_t t0;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:nested:compose /go/ { @in = count(); @ev[(arg1 & 0x80000000) ? (arg1 & 0xff) : 0] = count();
	printf("%10d t%d -> root intr12=%#lx rflags=%#lx\n", (timestamp - t0)/1000, tid, arg1, arg4 >> 32); }
fbt:vmm-restore:nested_l2_exit:entry /go/ { @ex[*(uint32_t *)((uintptr_t)arg1 + 20) & 0xffff] = count();
	printf("%10d t%d root esce %d rip=%#lx rcx=%#lx\n", (timestamp - t0)/1000, tid, *(uint32_t *)((uintptr_t)arg1 + 20) & 0xffff,
	    *(uint64_t *)((uintptr_t)arg1 + 8), *(uint64_t *)((uintptr_t)arg0 + 128)); }
fbt:vmm-restore:vlapic_set_intr_ready:entry /go/ { @v[arg1] = count(); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/ { @t = count(); }
tick-1s /go/ { printf("=== %d s: ", (timestamp - t0)/1000000000); printa("ingressi root %@d; ", @in); printa("timer %@d\n", @t);
	printa("    iniettato %#x: %@d\n", @ev); printa("    vlapic vettore %#x: %@d\n", @v); printa("    root esce motivo %d: %@d\n", @ex);
	clear(@in); clear(@t); clear(@ev); clear(@v); clear(@ex); }
fbt:vmm-restore:vm_suspend:entry /go/ { printf("%10d VM_SUSPEND how=%d\n", (timestamp - t0)/1000, (int)arg1); exit(0); }
tick-1s /go && timestamp - t0 > 1800000000000/ { exit(0); }
