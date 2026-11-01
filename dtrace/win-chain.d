#pragma D option quiet
#pragma D option bufsize=48m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Astra #4 priorita' 3: la catena completa del clock, per
 * vedere se l'ULTIMA sequenza IPI prima di ICR=0 e' consegnata ed EOI'd o si
 * rompe. timer cpu0 (SET/FIRE) -> ICR-send (IPI) -> IRR-set sul bersaglio ->
 * NOTIFY -> ACCEPT (IRR->ISR) -> EOI -> riarmo. Vettori del clock: 0xd2 (IPI
 * clock), 0x2f/0xec/0xed (IPI), 0xef (timer). Offset: vlapic vcpuid+16,
 * apic_page+24; icr_timer+896, icrlo+0x300. struct vcpu vcpuid+36.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

fbt:vmm-restore:vlapic_icrtmr_write_handler:entry /go/
{ this->p = *(uintptr_t *)(arg0 + 24);
  printf("%10d cpu%d TIMER-SET icr=%u\n", (timestamp - t0)/1000, *(int *)(arg0 + 16),
      *(uint32_t *)(this->p + 896)); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/
{ printf("%10d cpu%d TIMER-FIRE\n", (timestamp - t0)/1000, *(int *)(arg0 + 16)); }

fbt:vmm-restore:vlapic_icrlo_write_handler:entry /go/
{ this->p = *(uintptr_t *)(arg0 + 24);
  printf("%10d cpu%d ICR-send vett=%#x\n", (timestamp - t0)/1000, *(int *)(arg0 + 16),
      *(uint32_t *)(this->p + 0x300) & 0xff); }

fbt:vmm-restore:vlapic_set_intr_ready:entry
/go && (arg1 == 0xd2 || arg1 == 0x2f || arg1 == 0xec || arg1 == 0xed || arg1 == 0xef)/
{ printf("%10d cpu%d IRR-set vett=%#x\n", (timestamp - t0)/1000, *(int *)(arg0 + 16), (int)arg1); }

fbt:vmm-restore:vlapic_intr_accepted:entry
/go && (arg1 == 0xd2 || arg1 == 0x2f || arg1 == 0xec || arg1 == 0xed || arg1 == 0xef)/
{ printf("%10d cpu%d ACCEPT vett=%#x\n", (timestamp - t0)/1000, *(int *)(arg0 + 16), (int)arg1); }

fbt:vmm-restore:vlapic_process_eoi:entry /go/
{ printf("%10d cpu%d EOI\n", (timestamp - t0)/1000, *(int *)(arg0 + 16)); }

fbt:vmm-restore:vcpu_notify_lapic:entry /go/
{ printf("%10d cpu%d NOTIFY\n", (timestamp - t0)/1000, *(int *)(arg0 + 36)); }

vmm:vmx:exit:entry /go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 12/
{ printf("%10d cpu%d HLT\n", (timestamp - t0)/1000, (int)arg1); }

tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }
