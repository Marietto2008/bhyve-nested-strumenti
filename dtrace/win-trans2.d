#pragma D option quiet
#pragma D option bufsize=8m
#pragma D option switchrate=1hz
/* Transizione verso lo stallo: eventi RARI stampati subito (flush ogni s); gli IRR aggregati.
 * tid distingue i due vCPU. Leggere il tail del file quando la VM e' bloccata. */
int go; int64_t t0;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; printf("%10d t%d PRIMO INGRESSO L2\n", 0, tid); }
vmm:vmx:exit:entry /go/ { this->r = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	if (this->r == 12) printf("%10d t%d HLT rip=%#lx\n", (timestamp-t0)/1000, tid, *(uint64_t *)((uintptr_t)arg2 + 8)); }
vmm:vmx:nested:compose /go/ { @ent[tid] = count();
	if (arg1 & 0x80000000) printf("%10d t%d ENTRA-L2 EVENTO intr12=%#lx\n", (timestamp-t0)/1000, tid, arg1); }
fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/ { printf("%10d t%d TIMER-ARMATO\n", (timestamp-t0)/1000, tid); }
fbt:vmm-restore:vlapic_fire_lvt:entry /go && arg1 == 0/ { printf("%10d t%d TIMER-SCATTA\n", (timestamp-t0)/1000, tid); }
fbt:vmm-restore:vcpu_notify_event:entry /go/ { printf("%10d t%d NOTIFY\n", (timestamp-t0)/1000, tid); }
fbt:vmm-restore:vlapic_set_intr_ready:entry /go/ { @irr[arg1] = count(); }
tick-2s /go/ { printf("--- %d ms: ingressi L2 ", (timestamp-t0)/1000000); printa("t%d=%@d ", @ent); printf("\n"); }
