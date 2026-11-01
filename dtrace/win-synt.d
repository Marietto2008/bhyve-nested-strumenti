#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option switchrate=1hz
/* Fino allo SYNTHETIC_WATCHDOG_TIMEOUT: flusso del timer sintetico e del preemption timer.
 * Se la serie dei tick (vettore 239 / reason 52) si interrompe prima del crash, li' si perde. */
int go; int64_t t0, last239, lastpt;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 52/ {
	printf("%10d t%d PREEMPT-TIMER exit (gap %d ms)\n", (timestamp-t0)/1000, tid, lastpt?(timestamp-lastpt)/1000000:0); lastpt=timestamp; }
vmm:vmx:nested:chkev /go && arg2 && (int)arg3 == 239/ {
	printf("%10d t%d TICK-SINT 239 (gap %d ms)\n", (timestamp-t0)/1000, tid, last239?(timestamp-last239)/1000000:0); last239=timestamp; }
vmm:vmx:nested:compose /go && (arg1 & 0xff) == 0xef && (arg1 & 0x80000000)/ { @inj239=count(); }
vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 12/ { @hlt[tid]=count(); }
tick-5s /go/ { printf("--- %d s: ", (timestamp-t0)/1000000000); printa("inj239=%@d ", @inj239); printa("hlt t%d=%@d ", @hlt); printf("\n"); }
