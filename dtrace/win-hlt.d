#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 — Astra Fase 1-bis: audit degli HLT nested.
 * Invariante: un HLT eseguito da L2 (in_l2=1) con VMCS12.HLT_EXITING deve
 * essere RIFLESSO a L1, non gestito nel ramo L1 di L0. La sonda SDT
 * vmm:vmx:exit:halt scatta SOLO quando l'uscita HLT raggiunge lo switch di
 * L1 (cioe' NON e' stata riflessa/gestita dal routing nested a vmx.c:2684).
 * Quindi: exit:halt con in_l2=1 == un HLT di L2 arrivato al gestore L1 = BUG.
 * in_l2 e' letto in exit:entry (vmx_vcpu.nested +696, in_l2 +1; reason +20).
 */
int go; int64_t t0; int hlt_l2; int hlt_l1; int halt_sw_l2; int halt_sw_l1; int reflected;

vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }

vmm:vmx:exit:entry /go/
{
	this->r = *(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff;
	this->n = *(uintptr_t *)(arg0 + 696);
	self->l2 = this->n ? *(uint8_t *)(this->n + 1) : 0;
	if (this->r == 12) {
		if (self->l2) { hlt_l2++;
		    printf("%10d HLT-exit in_l2=1 (L2)\n", (timestamp - t0)/1000); }
		else hlt_l1++;
	}
}

/* scatta solo se l'HLT NON e' stato riflesso dal routing nested */
vmm:vmx:exit:halt /go/
{
	if (self->l2) { halt_sw_l2++;
	    printf("%10d *** exit:halt con in_l2=1 -- HLT di L2 al gestore L1 = BUG\n",
	        (timestamp - t0)/1000); }
	else halt_sw_l1++;
}

fbt:vmm-restore:nested_reflect_to_l1:entry /go/ { reflected++; }

tick-5s /go/
{
	printf("--- %ds | HLT-exit L2=%d L1=%d | exit:halt(L1-switch) da-L2=%d da-L1=%d | riflessi tot=%d\n",
	    (timestamp - t0)/1000000000, hlt_l2, hlt_l1, halt_sw_l2, halt_sw_l1, reflected);
}
