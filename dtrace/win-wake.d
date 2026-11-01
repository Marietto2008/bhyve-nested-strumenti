#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option switchrate=1hz
/* Corsa di risveglio sotto Hyper-V: per CPU (vcpuid), HLT/park, interrupt in attesa, notify, e
 * il flusso delle uscite. struct vcpu: vcpuid +36. exit:entry arg1=vcpuid. */
int go; int64_t t0; int lasthlt[int];
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:exit:entry /go/ { this->r = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	if (this->r == 12) { printf("%10d cpu%d HLT (park)\n", (timestamp-t0)/1000, (int)arg1); lasthlt[(int)arg1]=1; }
	else if (lasthlt[(int)arg1]) { printf("%10d cpu%d SVEGLIA (uscita motivo %d)\n", (timestamp-t0)/1000, (int)arg1, this->r); lasthlt[(int)arg1]=0; } }
fbt:vmm-restore:lapic_set_intr:entry /go/ { printf("%10d cpu%d <- interrupt in attesa vettore=%#x (level=%d)\n",
	(timestamp-t0)/1000, *(int *)(arg0 + 36), (int)arg1, (int)arg2); }
fbt:vmm-restore:vcpu_notify_event:entry /go/ { printf("%10d cpu%d <- NOTIFY (risveglio)\n", (timestamp-t0)/1000, *(int *)(arg0 + 36)); }
fbt:vmm-restore:vcpu_notify_lapic:entry /go/ { printf("%10d cpu%d <- NOTIFY-LAPIC\n", (timestamp-t0)/1000, *(int *)(arg0 + 36)); }
tick-3s /go/ { printf("--- %d s ---\n", (timestamp-t0)/1000000000); }
