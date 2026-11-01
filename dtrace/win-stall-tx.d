#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Transizione verso lo stallo (clona win-timer2.d e
 * aggiunge il clock IPI 0xd2 e la notify per-evento). Domanda: al momento in
 * cui il ciclo del clock si rompe, cpu0 DISARMA il suo timer (icr=0) o il
 * callout smette di scattare? E l'ultimo 0xd2 verso l'altra cpu, e l'ultima
 * notify (risveglio). switchrate=2hz: il file si riempie man mano, lo stallo
 * e' il silenzio DOPO l'ultimo record (niente ring: non perdo i dati).
 * Offset: vlapic.vcpuid +16, apic_page +24; icr_timer +896, dcr +992,
 * lvt_timer +800. struct vcpu.vcpuid +36. exit:entry arg1=vcpuid,
 * arg2=vmexit (+20 reason).
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

/* arma/disarma del timer LAPIC: icr=valore iniziale (0 = disarmo), lvt */
fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%10d cpu%d TIMER-SET icr=%u dcr=%#x lvt=%#x\n", (timestamp - t0)/1000,
	    *(int *)(arg0 + 16), *(uint32_t *)(this->p + 896),
	    *(uint32_t *)(this->p + 992), *(uint32_t *)(this->p + 800));
}

/* il timer LAPIC scatta (la sorgente del tick) */
fbt:vmm-restore:vlapic_callout_handler:entry /go/
{
	printf("%10d cpu%d TIMER-SCATTA\n", (timestamp - t0)/1000, *(int *)(arg0 + 16));
}

/* vettore >= 0xd0 reso pronto nel vlapic di destinazione (il clock IPI 0xd2) */
fbt:vmm-restore:vlapic_set_intr_ready:entry /go && arg1 >= 0xd0/
{
	printf("%10d -> vett %#x su cpu%d\n", (timestamp - t0)/1000, (int)arg1,
	    *(int *)(arg0 + 16));
}

/* risveglio della vCPU */
fbt:vmm-restore:vcpu_notify_event:entry /go/
{
	printf("%10d cpu%d NOTIFY\n", (timestamp - t0)/1000, *(int *)(arg0 + 36));
}

/* HLT (parcheggio) */
vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 12/
{
	printf("%10d cpu%d HLT\n", (timestamp - t0)/1000, (int)arg1);
}

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
