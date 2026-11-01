#pragma D option quiet
#pragma D option switchrate=1hz
/*
 * Claude 21/10/2026 -- prova .wslconfig (parere #26 §9): per minuto, con l'ora,
 * INVEPT esaminati, P0, voci EPT12 cambiate (totale e livello 0), permessi e
 * indirizzo (minimi: saturano a 1023 per INVEPT), EPT violation dall'L2.
 * Modulo diagnostico 3c3f16e con hw.vmm.vmx.vept_diag=1.
 */
vmm:vmx:nested:veptdiag { self->tch = (int)arg3; self->ech = arg4; }
vmm:vmx:nested:veptdiag2
{
	this->pulito = self->tch == 0 && arg3 == 0 && (arg4 & 0xffffffff) == 0 && (arg4 >> 32) == 0;
	@m["a INVEPT esaminati"] = sum(1);
	@m["b INVEPT senza modifiche (P0)"] = sum(this->pulito);
	@m["c voci EPT12 cambiate"] = sum(self->ech);
	@m["d   di cui livello 0"] = sum(arg1 & 0xffff);
	@m["e   permessi (minimo)"] = sum((arg2 >> 10) & 0x3ff);
	@m["f   indirizzo (minimo)"] = sum(arg2 & 0x3ff);
}
fbt::nested_l2_exit:entry /(*(uint32_t *)(arg1 + 0x14) & 0xffff) == 48/ { @m["g EPT violation dall'L2"] = sum(1); }
tick-60s
{
	printf("=== %Y\n", walltimestamp);
	printa("  %-32s %@d\n", @m); clear(@m);
}
