#pragma D option quiet
#pragma D option bufsize=48m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Esp. #2 quater: quadro COMBINATO alla transizione.
 * Timer LAPIC (arma/disarma + scatto), IPI inviati (ICR mmio, con vettore),
 * consegna all'IRR, notify, HLT. Obiettivo: all'ultimo HLT di cpu0, qual e'
 * lo stato del suo timer? disarmato (icr=0)? armato lontano? e il callout
 * scatta o no? Offset: vlapic vcpuid+16, apic_page+24; icr_timer+896,
 * dcr+992, lvt_timer+800; icrlo a apic_page+0x300. vcpu vcpuid+36.
 * exit:entry arg1=vcpuid, arg2=vmexit(+20 reason).
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d cpu%d TIMER-SET icr=%u dcr=%#x lvt=%#x\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 16), *(uint32_t *)(this->p + 896),
	    *(uint32_t *)(this->p + 992), *(uint32_t *)(this->p + 800));
}
fbt:vmm-restore:vlapic_callout_handler:entry /go/
{ printf("%10d cpu%d TIMER-SCATTA\n", (timestamp - t0)/1000, *(int *)(arg0 + 16)); }

fbt:vmm-restore:vlapic_icrlo_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d cpu%d ICR vett=%#x\n", (timestamp - t0)/1000, *(int *)(arg0 + 16),
	    *(uint32_t *)(this->p + 0x300) & 0xff);
}
fbt:vmm-restore:vlapic_set_intr_ready:entry
/go && (arg1 == 0xd2 || arg1 == 0x2f || arg1 == 0xec || arg1 == 0xed || arg1 == 0xef || arg1 == 0xff)/
{ printf("%10d -> IRR vett=%#x su cpu%d\n", (timestamp - t0)/1000, (int)arg1, *(int *)(arg0 + 16)); }

fbt:vmm-restore:vcpu_notify_lapic:entry /go/
{ printf("%10d cpu%d NOTIFY\n", (timestamp - t0)/1000, *(int *)(arg0 + 36)); }
vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 12/
{ printf("%10d cpu%d HLT\n", (timestamp - t0)/1000, (int)arg1); }

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
