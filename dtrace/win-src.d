#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Esp. #2 ter: il PRODUTTORE dei risvegli e il momento in
 * cui cessano. Chi invia gli IPI (scrittura ICR) e con quale vettore/destinazione;
 * cosa arriva all'IRR del destinatario (set_intr_ready); le notify (wakeup);
 * gli HLT. Distingue GENERAZIONE (ICR write) da CONSEGNA (set_intr_ready+notify).
 * x2APIC ICR = WRMSR 0x830 (vett=val&0xff, dest=val>>32, mode=(val>>8)&7).
 * MMIO ICR = icrlo a apic_page+0x300. Offset: vlapic vcpuid+16, apic_page+24;
 * struct vcpu vcpuid+36. exit:entry arg1=vcpuid, arg2=vmexit(+20 reason).
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

/* IPI inviato da L1 via x2APIC (ICR = MSR 0x830) */
fbt:vmm-restore:lapic_wrmsr:entry /go && arg1 == 0x830/
{
	printf("%10d cpu%d ICR-x2 vett=%#x dest=%d mode=%#x\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 36), (int)(arg2 & 0xff), (int)(arg2 >> 32),
	    (int)((arg2 >> 8) & 0x7));
}
/* IPI inviato da L1 via MMIO (icrlo) */
fbt:vmm-restore:vlapic_icrlo_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d cpu%d ICR-mmio icrlo=%#x\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 16), *(uint32_t *)(this->p + 0x300));
}
/* vettore reso pronto nell'IRR del destinatario (consegna) */
fbt:vmm-restore:vlapic_set_intr_ready:entry
/go && (arg1 == 0xd2 || arg1 == 0xec || arg1 == 0xed || arg1 == 0xef || arg1 == 0xff)/
{
	printf("%10d -> IRR vett=%#x su cpu%d\n", (timestamp - t0)/1000, (int)arg1,
	    *(int *)(arg0 + 16));
}
/* risvegli */
fbt:vmm-restore:vcpu_notify_event:entry /go/
{ printf("%10d cpu%d NOTIFY-ev\n", (timestamp - t0)/1000, *(int *)(arg0 + 36)); }
fbt:vmm-restore:vcpu_notify_lapic:entry /go/
{ printf("%10d cpu%d NOTIFY-lapic\n", (timestamp - t0)/1000, *(int *)(arg0 + 36)); }
/* HLT */
vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 12/
{ printf("%10d cpu%d HLT\n", (timestamp - t0)/1000, (int)arg1); }

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
