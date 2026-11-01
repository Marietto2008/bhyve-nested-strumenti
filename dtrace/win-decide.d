#pragma D option quiet
#pragma D option bufsize=64m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Esp. #2, la DECISIONE: cosa fa cpu0 subito prima di
 * abbandonare il timer LAPIC. Traccio le scritture del timer (icr) e TUTTI gli
 * accessi ai MSR sintetici Hyper-V (0x40000000-0x400000FF: reference counter
 * 0x20, reference-TSC 0x21, SCONTROL/SINT 0x80-0x9F, STIMER 0xB0-0xB7,
 * GUEST_IDLE 0xF0), piu' TSC-deadline 0x6e0. Obiettivo: vedere l'ultima lettura/
 * scrittura HV prima del 'TIMER-SET icr=0' e capire a quale sorgente Hyper-V
 * crede di affidarsi. Offset: vlapic vcpuid+16, apic_page+24 (icr+896);
 * vmx_vcpu vcpuid+704.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d cpu%d TIMER-SET icr=%u\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 16), *(uint32_t *)(this->p + 896));
}

fbt:vmm-restore:vmx_rdmsr:entry
/go && ((arg1 >= 0x40000000 && arg1 <= 0x400000ff) || arg1 == 0x6e0)/
{ printf("%10d cpu%d RDMSR %#lx\n", (timestamp - t0)/1000, *(int *)(arg0 + 704), arg1); }

fbt:vmm-restore:vmx_wrmsr:entry
/go && ((arg1 >= 0x40000000 && arg1 <= 0x400000ff) || arg1 == 0x6e0)/
{ printf("%10d cpu%d WRMSR %#lx = %#lx\n", (timestamp - t0)/1000, *(int *)(arg0 + 704), arg1, arg2); }

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
