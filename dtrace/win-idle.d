#pragma D option quiet
#pragma D option bufsize=64m
#pragma D option switchrate=10hz
/* Windows 11 + Hyper-V: cosa fa Hyper-V (L1) prima di fermarsi in HLT col timer spento.
 * Da 450 ms dopo il primo ingresso in L2. vmx_vcpu: rcx +128, rax +152, rdx +120. */
int go; int64_t t0;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:exit:entry /go && timestamp - t0 > 450000000/ {
	this->e = (uintptr_t)arg2; this->r = *(uint32_t *)(this->e + 20) & 0xffff;
	printf("%9d uscita motivo %d qual=%#lx rip=%#lx\n", (timestamp - t0)/1000, this->r,
	    *(uint64_t *)(this->e + 24), *(uint64_t *)(this->e + 8));
}
fbt:vmm-restore:vmx_get_guest_reg:entry { self->gr = arg1; }
vmm:vmx:nested:compose /go && timestamp - t0 > 450000000/ { printf("%9d   -> ingresso L2 intr12=%#lx\n", (timestamp - t0)/1000, arg1); }
fbt:vmm-restore:nested_l2_exit:entry /go && timestamp - t0 > 450000000/ { printf("%9d      (dall'L2)\n", (timestamp - t0)/1000); }
fbt:vmm-restore:lapic_mmio_write:entry /go && timestamp - t0 > 450000000/ { printf("%9d   APIC W off=%#lx val=%#lx\n", (timestamp - t0)/1000, arg1 & 0xfff, arg2); }
fbt:vmm-restore:lapic_wrmsr:entry /go && timestamp - t0 > 450000000/ { printf("%9d   x2APIC W msr=%#lx val=%#lx\n", (timestamp - t0)/1000, arg1, arg2); }
fbt:vmm-restore:vhpet_mmio_write:entry /go && timestamp - t0 > 450000000/ { printf("%9d   HPET W off=%#lx val=%#lx\n", (timestamp - t0)/1000, arg1 & 0x3ff, arg2); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/ { printf("%9d   timer APIC di Hyper-V scatta\n", (timestamp - t0)/1000); }
fbt:vmm-restore:vlapic_set_intr_ready:entry /go && timestamp - t0 > 450000000/ { printf("%9d   vettore %#x verso il vlapic\n", (timestamp - t0)/1000, arg1); }
fbt:vmm-restore:vhpet_timer_interrupt:entry /go/ { printf("%9d   interrupt HPET\n", (timestamp - t0)/1000); }
tick-1s /go && timestamp - t0 > 8000000000/ { exit(0); }
