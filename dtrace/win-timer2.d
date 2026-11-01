#pragma D option quiet
#pragma D option bufsize=8m
#pragma D option switchrate=1hz
/* Timer del vlapic di Hyper-V alla transizione: ogni scrittura ICR (valore!), ogni scatto del
 * callout, ogni reset del callout, notify, e wrmsr 0x6e0 (TSC-deadline). apic_page=vlapic+24;
 * icr +896, dcr +992, lvt +800. */
int go; int64_t t0;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/ { this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d t%d ICR-WRITE icr=%u dcr=%#x lvt=%#x\n", (timestamp-t0)/1000, tid,
	    *(uint32_t *)(this->p + 896), *(uint32_t *)(this->p + 992), *(uint32_t *)(this->p + 800)); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/ { printf("%10d t%d CALLOUT-SCATTA\n", (timestamp-t0)/1000, tid); }
fbt:vmm-restore:vcpu_notify_event:entry /go/ { @nt = count(); }
fbt:vmm-restore:lapic_wrmsr:entry /go && arg1 == 0x6e0/ { printf("%10d t%d MSR-TSCDEADLINE val=%#lx\n", (timestamp-t0)/1000, tid, arg2); }
vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 12/ { printf("%10d t%d HLT\n", (timestamp-t0)/1000, tid); }
tick-2s /go/ { printf("--- %d ms, notify finora ", (timestamp-t0)/1000000); printa("%@d\n", @nt); }
