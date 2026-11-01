#pragma D option quiet
#pragma D option bufpolicy=ring
#pragma D option bufsize=32m
/* Windows 11 + Hyper-V, 2 CPU: cosa succede quando la root si ferma (buffer circolare: restano
 * gli ultimi record). tid = thread del vCPU. vmx_vcpu: rcx +128, rax +152, rdx +120. */
int go; int64_t t0;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
fbt:vmm-restore:nested_l2_exit:entry /go/ {
	this->r = *(uint32_t *)((uintptr_t)arg1 + 20) & 0xffff;
	printf("%10d t%d L2 esce %d rip=%#lx rcx=%#lx\n", (timestamp - t0)/1000, tid, this->r,
	    *(uint64_t *)((uintptr_t)arg1 + 8), *(uint64_t *)((uintptr_t)arg0 + 128)); }
vmm:vmx:nested:compose /go/ { printf("%10d t%d -> L2 intr12=%#lx rflags=%#lx\n", (timestamp - t0)/1000, tid, arg1, arg4 >> 32); }
vmm:vmx:nested:chkev /go && arg2/ { printf("%10d t%d    chkev vettore %#x per Hyper-V\n", (timestamp - t0)/1000, tid, arg3); }
fbt:vmm-restore:lapic_mmio_write:entry /go && ((arg1 & 0xfff) == 0x300 || (arg1 & 0xfff) == 0x310)/ { printf("%10d t%d    Hyper-V APIC W off=%#lx val=%#lx\n", (timestamp - t0)/1000, tid, arg1 & 0xfff, arg2); }
fbt:vmm-restore:lapic_wrmsr:entry /go && arg1 == 0x830/ { printf("%10d t%d    Hyper-V x2APIC ICR=%#lx\n", (timestamp - t0)/1000, tid, arg2); }
fbt:vmm-restore:vlapic_icrlo_write_handler:entry /go/ { printf("%10d t%d    IPI (ICR) scritto\n", (timestamp - t0)/1000, tid); }
fbt:vmm-restore:vlapic_set_intr_ready:entry /go/ { printf("%10d t%d    vettore %#x -> vlapic %p\n", (timestamp - t0)/1000, tid, arg1, arg0); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/ { printf("%10d t%d    timer di Hyper-V scatta\n", (timestamp - t0)/1000, tid); }
tick-1s /go && timestamp - t0 > 15000000000/ { exit(0); }
