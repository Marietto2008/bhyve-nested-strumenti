#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Esp. #2, secondo giro. win-stall-tx.d + sorgenti di
 * tempo ALTERNATIVE: HPET e i MSR sintetici di Hyper-V. Domanda: a t~0,82s
 * cpu0 disarma il timer LAPIC (icr=0) e si affida a cos'altro? Qui traccio
 * anche: scritture HPET, interrupt HPET, e WRMSR/RDMSR nel range sintetico
 * Hyper-V (0x40000080-0x400000FF: SynIC SCONTROL/SINT, STIMER config/count
 * 0x400000B0-B7, GUEST_IDLE 0x400000F0).
 * Offset: vlapic.vcpuid +16, apic_page +24; icr_timer +896, dcr +992,
 * lvt_timer +800. struct vcpu.vcpuid +36. vmx_vcpu.vcpuid +704.
 * exit:entry arg1=vcpuid, arg2=vmexit (+20 reason).
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d cpu%d TIMER-SET icr=%u lvt=%#x\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 16), *(uint32_t *)(this->p + 896),
	    *(uint32_t *)(this->p + 800));
}
fbt:vmm-restore:vlapic_callout_handler:entry /go/
{ printf("%10d cpu%d TIMER-SCATTA\n", (timestamp - t0)/1000, *(int *)(arg0 + 16)); }

/* HPET: scritture dei registri e interrupt generato */
fbt:vmm-restore:vhpet_mmio_write:entry /go/
{ printf("%10d HPET-W off=%#lx val=%#lx\n", (timestamp - t0)/1000, arg1 & 0x3ff, arg2); }
fbt:vmm-restore:vhpet_timer_interrupt:entry /go/
{ printf("%10d HPET-INT\n", (timestamp - t0)/1000); }

/* MSR sintetici Hyper-V (SynIC/STIMER/guest-idle): scritture e letture */
fbt:vmm-restore:vmx_wrmsr:entry /go && arg1 >= 0x40000080 && arg1 <= 0x400000ff/
{ printf("%10d cpu%d HV-WRMSR %#lx = %#lx\n", (timestamp - t0)/1000, *(int *)(arg0 + 704), arg1, arg2); }
fbt:vmm-restore:vmx_rdmsr:entry /go && arg1 >= 0x400000b0 && arg1 <= 0x400000ff/
{ printf("%10d cpu%d HV-RDMSR %#lx\n", (timestamp - t0)/1000, *(int *)(arg0 + 704), arg1); }

/* clock IPI 0xd2 e simili, notify, HLT */
fbt:vmm-restore:vlapic_set_intr_ready:entry /go && arg1 >= 0xd0/
{ printf("%10d -> vett %#x su cpu%d\n", (timestamp - t0)/1000, (int)arg1, *(int *)(arg0 + 16)); }
fbt:vmm-restore:vcpu_notify_event:entry /go/
{ printf("%10d cpu%d NOTIFY\n", (timestamp - t0)/1000, *(int *)(arg0 + 36)); }
vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 12/
{ printf("%10d cpu%d HLT\n", (timestamp - t0)/1000, (int)arg1); }

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
