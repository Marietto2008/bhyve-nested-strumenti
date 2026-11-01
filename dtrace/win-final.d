#pragma D option quiet
#pragma D option bufsize=64m
#pragma D option switchrate=4hz
#pragma D option dynvarsize=16m
/*
 * Claude 20/10/2026 -- verifica di 0b1a0f3 + 22dc5d5 con le metriche del
 * parere #16 di Astra. Da usare con hw.vmm.vmx.diag_vec=45 (int 0x2d).
 *   1 synth_exit con IDT_VECTORING 0xd1 prima dell'ingresso in L2 ......... 0
 *   2 iniezioni software di int 0x2d con ENTRY_INST_LENGTH != 2 ............ 0
 *   3 interrupt dell'L1 rinviati e mai consegnati ............................ 0
 *   4 winexit owner=1 (finestra dell'L1 consumata da L0) ..................... 0
 *   5 VM-entry fallite ......................................................... 0
 *   6 tick (0xd1 chiesti da Hyper-V nel VMCS12) presenti fino alla fine
 *   7 latenza dei rinvii (distribuzione e massimo)
 * Schermate blu: le rileva il banco leggendo il pagefile dopo ogni corsa.
 */
int go; int64_t t0;
int64_t aperto[int]; int akind[int]; int avec[int]; uint64_t ainfo[int];

vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

/* 6: i tick */
vmm:vmx:nested:compose /go && (arg1 & 0x800000ff) == 0x800000d1/
{ @tick = count(); @tick_ult = max((timestamp - t0) / 1000); }

/* 1 */
vmm:vmx:nested:synth_exit /go/
{
	@synth[(int)arg1] = count();
	if (((int)arg1 & 0xff) == 0xd1)
		printf("%10d !!! synth_exit idt=%#x VP%d\n", (timestamp - t0) / 1000,
		    (int)arg1, *(int *)(arg0 + 704));
}

/* 3 e 7: rinvii */
vmm:vmx:nested:defer /go/
{
	@rinvii[(int)arg1] = count();
	if (aperto[(int)arg0] == 0) {
		aperto[(int)arg0] = timestamp;
		akind[(int)arg0] = (int)arg1; avec[(int)arg0] = (int)arg3;
		ainfo[(int)arg0] = arg2;
	}
}
fbt:vmm-restore:nested_check_events:entry /go/ { self->nce = *(int *)(arg0 + 704) + 1; }
fbt:vmm-restore:nested_check_events:return /self->nce && arg1 && aperto[self->nce - 1]/
{
	this->d = (timestamp - aperto[self->nce - 1]) / 1000;
	@lat = quantize(this->d); @lat_max = max(this->d); @chiusi = count();
	if (this->d > 1000)
		printf("%10d LUNGO LP%d rinvio di %d us  kind=%d vett_L1=%#x evento_L2=%#lx\n",
		    (timestamp - t0) / 1000, self->nce - 1, this->d,
		    akind[self->nce - 1], avec[self->nce - 1], ainfo[self->nce - 1]);
	aperto[self->nce - 1] = 0;
}
fbt:vmm-restore:nested_check_events:return /self->nce/ { self->nce = 0; }

/* 2: int 0x2d con la lunghezza all'ingresso hardware */
vmm:vmx:nested:diag_entry { self->ei = arg1 & 0xffffffff; self->rip = arg2; self->us = (timestamp - t0) / 1000; }
vmm:vmx:nested:diag_more
{
	this->ilen = (int)(arg2 >> 32);
	@ilen[this->ilen] = count();
	printf("%10d INJ VP%d ei=%#x rip=%#lx ENTRY_INST_LENGTH=%d %s\n", self->us, (int)arg0,
	    (int)self->ei, self->rip, this->ilen, this->ilen == 2 ? "" : "!!! LUNGHEZZA SBAGLIATA");
}

/* 4 e 5 */
vmm:vmx:nested:winexit /go && arg1/ { printf("%10d !!! winexit owner=1 VP%d\n", (timestamp - t0) / 1000, (int)arg0); }
vmm:vmx:nested:winexit /go/ { @win[(int)arg1] = count(); }
vmm:vmx:nested:vmfail /go/ { @vmfail = count(); printf("%10d !!! VM-entry fallita\n", (timestamp - t0) / 1000); }

tick-5s /go/
{
	printf("=== %d s\n", (timestamp - t0) / 1000000000);
	printa("  tick chiesti (0xd1) = %@d   ultimo = ", @tick); printa("%@d us\n", @tick_ult);
	printa("  rinvii kind %d = %@d\n", @rinvii);
	printa("  rinvii chiusi = %@d   latenza max = ", @chiusi); printa("%@d us\n", @lat_max);
	printa("  synth_exit idt=%#x = %@d\n", @synth);
	printa("  int 0x2d ENTRY_INST_LENGTH=%d : %@d\n", @ilen);
	printa("  winexit owner=%d : %@d\n", @win);
	printa("  vmfail = %@d\n", @vmfail);
	printa("  latenza (us): %@d\n", @lat);
	printf("  aperti: LP0 da %d us, LP1 da %d us\n",
	    aperto[0] ? (timestamp - aperto[0]) / 1000 : 0,
	    aperto[1] ? (timestamp - aperto[1]) / 1000 : 0);
}
END { printa("  latenza dei rinvii (us): %@d\n", @lat); }
