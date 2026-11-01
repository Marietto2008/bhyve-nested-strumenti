#pragma D option quiet
#pragma D option bufpolicy=ring
#pragma D option bufsize=16m
/* Transizione verso lo stallo di Windows+Hyper-V: buffer circolare degli ultimi eventi.
 * Si legge fermando dtrace quando la VM e' bloccata. tid distingue i due vCPU. */
int go; int64_t t0;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:exit:entry /go/ { this->r = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	if (this->r == 12) printf("%10d t%d HLT (rip=%#lx)\n", (timestamp-t0)/1000, tid, *(uint64_t *)((uintptr_t)arg2 + 8)); }
vmm:vmx:nested:compose /go/ { printf("%10d t%d ENTRA-L2 intr12=%#lx rflags=%#lx\n", (timestamp-t0)/1000, tid, arg1, arg4>>32); }
fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/ { printf("%10d t%d TIMER-ARMATO\n", (timestamp-t0)/1000, tid); }
fbt:vmm-restore:vlapic_fire_lvt:entry /go && arg1 == 0/ { printf("%10d t%d TIMER-SCATTA\n", (timestamp-t0)/1000, tid); }
fbt:vmm-restore:vlapic_set_intr_ready:entry /go/ { printf("%10d t%d IRR vettore=%#x vlapic=%p\n", (timestamp-t0)/1000, tid, arg1, arg0); }
fbt:vmm-restore:vcpu_notify_event:entry /go/ { printf("%10d t%d NOTIFY\n", (timestamp-t0)/1000, tid); }
