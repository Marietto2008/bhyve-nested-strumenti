#pragma D option quiet
#pragma D option bufsize=48m
#pragma D option aggsize=16m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 -- Astra #11 Fase A/B: la sorte dell'interrupt 0xd1 (SINT3 di STIMER0),
 * etichettata per VTL. SynIC/STIMER/LAPIC sono stato PRIVATO di ciascun VTL, quindi ogni
 * evento va attribuito alla coppia (VP, EPTP12).
 * Sonde con argomenti verificati:
 *   nested:compose(vcpu, VMCS12 ENTRY_INTR_INFO, pin, proc, RFLAGS<<32|interruptibility)
 *   nested:vmfail(vcpu, n)
 *   nested_l2_exit(vcpu, vmexit): rip +8, reason +20, qual +24
 * Offset: vmx_vcpu.vcpuid +704, .nested +0x2b8; vmx_nested.vept_eptp12 +0x4540.
 * Tutte le eta' sono in microsecondi dal primo ingresso in L2; i max() danno l'ISTANTE
 * dell'ultimo evento, da confrontare col DeliveryTime del messaggio SynIC.
 */
int go; int64_t t0;

vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp;
	printf("T0 walltimestamp=%d\n", walltimestamp); }

vmm:vmx:nested:compose /go/
{
	this->cpu = *(int *)(arg0 + 704);
	this->n = *(uintptr_t *)(arg0 + 0x2b8);
	this->e = this->n ? *(uint64_t *)(this->n + 0x4540) : 0;
	this->us = (timestamp - t0)/1000;
	@ingr[this->cpu, this->e] = count();
	@ultimo_ingr[this->cpu, this->e] = max(this->us);
	if (arg1 & 0x80000000) {
		@inj[this->cpu, this->e, arg1 & 0xff, (arg1 >> 8) & 7] = count();
		@ultima_inj[this->cpu, this->e, arg1 & 0xff] = max(this->us);
		printf("%10d VP%d VTL=%#lx INIETTA vett=%#x tipo=%d info=%#lx rflags=%#x intblk=%#x\n",
		    this->us, this->cpu, this->e, (int)(arg1 & 0xff), (int)((arg1 >> 8) & 7),
		    (uint64_t)arg1, (int)(arg4 >> 32), (int)(arg4 & 0xffffffff));
	}
}

vmm:vmx:nested:vmfail /go/
{
	this->cpu = *(int *)(arg0 + 704);
	this->n = *(uintptr_t *)(arg0 + 0x2b8);
	this->e = this->n ? *(uint64_t *)(this->n + 0x4540) : 0;
	@fail[this->cpu, this->e, (int)arg1] = count();
	printf("%10d VP%d VTL=%#lx VM-ENTRY FALLITA err=%d\n", (timestamp - t0)/1000,
	    this->cpu, this->e, (int)arg1);
}

fbt:vmm-restore:nested_l2_exit:entry /go/
{
	this->cpu = *(int *)(arg0 + 704);
	this->n = *(uintptr_t *)(arg0 + 0x2b8);
	this->e = this->n ? *(uint64_t *)(this->n + 0x4540) : 0;
	this->r = *(uint32_t *)(arg1 + 20) & 0xffff;
	@usc[this->cpu, this->e, this->r] = count();
	@ultima_usc[this->cpu, this->e] = max((timestamp - t0)/1000);
	@rip_usc[this->cpu, this->e] = max(*(uint64_t *)(arg1 + 8));
}

tick-5s /go/
{
	printf("=== %d s  wall=%d  (eta' = us dal primo ingresso in L2)\n",
	    (timestamp - t0)/1000000000, walltimestamp);
	printa("  ingressi   (VP%d, VTL %#lx) = %@d\n", @ingr);
	printa("  ult.ingr   (VP%d, VTL %#lx) = %@d us\n", @ultimo_ingr);
	printa("  ult.uscita (VP%d, VTL %#lx) = %@d us\n", @ultima_usc);
	printa("  rip uscita (VP%d, VTL %#lx) = %@#lx\n", @rip_usc);
	printa("  uscite     (VP%d, VTL %#lx) motivo %d = %@d\n", @usc);
	printa("  iniettato  (VP%d, VTL %#lx) vett %#x tipo %d = %@d\n", @inj);
	printa("  ult.iniez  (VP%d, VTL %#lx) vett %#x = %@d us\n", @ultima_inj);
	printa("  entry-fail (VP%d, VTL %#lx) err %d = %@d\n", @fail);
}
