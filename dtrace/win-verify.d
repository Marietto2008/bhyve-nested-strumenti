#pragma D option quiet
#pragma D option bufsize=64m
#pragma D option switchrate=4hz
#pragma D option dynvarsize=16m
/*
 * Claude 19/10/2026 -- verifica dei commit e8efe28 + 6496bc2 + 98c3fac con i
 * criteri del parere #15 di Astra.
 *   - uscite sintetiche che interrompono 0xd1 (synth_exit idt=0x800000d1): attese 0
 *   - interrupt dell'L1 RINVIATI (chkev pend=1 -> nested_check_events = 0) e
 *     poi CONSEGNATI (chkev pend=1 -> = 1): durata del rinvio, massimo,
 *     e rinvii mai seguiti da consegna
 *   - uscite INTR_WINDOW gestite da L0: owner 0 atteso, owner 1 = invariante violato
 *   - VM-entry fallite: attese 0
 *   - tick (0xd1 all'ingresso hardware) presenti anche dopo le collisioni
 */
int go; int64_t t0;
int64_t defer_t0[int];		/* inizio del rinvio in corso, per vCPU */

vmm:vmx:nested:enter_l2 /!go/
{ go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

vmm:vmx:nested:chkev /go && arg2/
{ self->pend = 1; self->pvec = (int)arg3; }

fbt:vmm-restore:nested_check_events:entry /go/ { self->nce = *(int *)(arg0 + 704) + 1; self->pend = 0; }
fbt:vmm-restore:nested_check_events:return /self->nce && self->pend/
{
	this->cpu = self->nce - 1;
	if (arg1 == 0) {
		/* l'L1 ha un interrupt pendente ma non si esce: RINVIO */
		@rinvii[this->cpu] = count();
		if (defer_t0[this->cpu] == 0) {
			defer_t0[this->cpu] = timestamp;
			@rinvii_iniziati[this->cpu] = count();
		}
	} else {
		@consegne[this->cpu] = count();
		if (defer_t0[this->cpu] != 0) {
			this->d = (timestamp - defer_t0[this->cpu]) / 1000;
			@durata_max[this->cpu] = max(this->d);
			@durata[this->cpu] = quantize(this->d);
			@rinvii_chiusi[this->cpu] = count();
			defer_t0[this->cpu] = 0;
		}
	}
}
fbt:vmm-restore:nested_check_events:return /self->nce/ { self->nce = 0; self->pend = 0; }

vmm:vmx:nested:synth_exit /go/
{
	this->cpu = *(int *)(arg0 + 704);
	@synth[this->cpu, (int)arg1] = count();
	if (((int)arg1 & 0xff) == 0xd1)
		printf("%10d !!! synth_exit idt=%#x su VP%d (interrompe il tick)\n",
		    (timestamp - t0) / 1000, (int)arg1, this->cpu);
}

vmm:vmx:nested:winexit /go/
{
	@win[(int)arg0, (int)arg1] = count();
	if (arg1)
		printf("%10d !!! winexit owner=1 VP%d p12=%#lx (INVARIANTE VIOLATO)\n",
		    (timestamp - t0) / 1000, (int)arg0, arg2);
}

vmm:vmx:nested:vmfail /go/
{
	@vmfail[*(int *)(arg0 + 704), (int)arg1] = count();
	printf("%10d !!! VM-entry fallita VP%d err=%d\n", (timestamp - t0) / 1000,
	    *(int *)(arg0 + 704), (int)arg1);
}

vmm:vmx:nested:diag_exit
{
	@tick[(int)arg0] = count();
	@tick_ult[(int)arg0] = max((timestamp - t0) / 1000);
}

tick-5s /go/
{
	printf("=== %d s\n", (timestamp - t0) / 1000000000);
	printa("  tick       VP%d = %@d\n", @tick);
	printa("  tick ult   VP%d = %@d us\n", @tick_ult);
	printa("  rinvii     LP%d = %@d (ingressi rinviati)\n", @rinvii);
	printa("  rinvii aperti LP%d = %@d\n", @rinvii_iniziati);
	printa("  rinvii chiusi LP%d = %@d\n", @rinvii_chiusi);
	printa("  consegne   LP%d = %@d\n", @consegne);
	printa("  durata max LP%d = %@d us\n", @durata_max);
	printa("  synth_exit LP%d idt=%#x = %@d\n", @synth);
	printa("  winexit    VP%d owner=%d = %@d\n", @win);
	printa("  vmfail     VP%d err=%d = %@d\n", @vmfail);
}
END
{
	printa("  durata del rinvio (us) LP%d %@d\n", @durata);
}
