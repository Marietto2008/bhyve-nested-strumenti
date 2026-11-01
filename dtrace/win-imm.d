#pragma D option quiet
#pragma D option switchrate=2hz
#pragma D option dynvarsize=128m
#pragma D option cleanrate=97hz
/*
 * Claude 21/10/2026 -- verifica dell'immediate exit (41e71d7), parere #24.
 * Invarianti:
 *  1 nessuna uscita sintetica con IDT_VECTORING valido (synth_exit)
 *  2 rinvii di tipo 2 (consegna interrotta) restano protetti: contati
 *  3 nessuna uscita 52 riflessa a Hyper-V (reflect con motivo 52)
 *  4 ogni immediate exit armata arriva, niente cicli: armate vs arrivate,
 *    e numero di rinvii ripetuti per intervallo
 * Latenza PER INTERVALLO (vCPU, vettore): apre al primo defer, conta i
 * successivi, chiude sull'uscita EXT_INT sintetica riflessa con quel vettore
 * (acknowledge-on-exit). Un campione per intervallo.
 * Offset (DWARF 41e71d7 da verificare: synth/synth_intr_info possono essere
 * spostati dai campi nuovi): vedi BEGIN.
 */
int64_t aperto[int, int];
int rip[int, int];
int64_t t0;

BEGIN { t0 = timestamp; }

vmm:vmx:nested:synth_exit /(arg1 & 0x80000000) != 0/
{ @n["1 synth_exit con IDT-vectoring valido"] = count();
  printf("%Y !!! synth_exit idt=%#x\n", walltimestamp, (int)arg1); }

vmm:vmx:nested:defer { @kind[(int)arg1] = count(); }

vmm:vmx:nested:immexit { @imm[(int)arg1, (int)arg2] = count(); }

vmm:vmx:nested:reflect
/(*(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 0x88 + 0x14) & 0xffff) == 52/
{ @n["3 uscita 52 riflessa all'L1"] = count();
  printf("%Y !!! uscita 52 riflessa a Hyper-V VP%d\n", walltimestamp, *(int *)(arg0 + 0x2c0)); }

vmm:vmx:nested:defer /aperto[(int)arg0, (int)arg3] == 0/
{ aperto[(int)arg0, (int)arg3] = timestamp; rip[(int)arg0, (int)arg3] = 0; @aperti = count(); }
vmm:vmx:nested:defer /aperto[(int)arg0, (int)arg3] != 0/
{ rip[(int)arg0, (int)arg3]++; }

vmm:vmx:nested:reflect
/(*(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 0x88 + 0x14) & 0xffff) == 1 &&
 *(uint8_t *)(*(uintptr_t *)(arg0 + 0x2b8) + $1) != 0/
{
	this->v = *(int *)(arg0 + 0x2c0);
	this->vec = (int)(*(uint32_t *)(*(uintptr_t *)(arg0 + 0x2b8) + $2) & 0xff);
	this->t = aperto[this->v, this->vec];
}
vmm:vmx:nested:reflect /this->t != 0/
{
	this->d = (timestamp - this->t) / 1000;
	@lat = quantize(this->d); @latmax = max(this->d); @chiusi = count();
	@rinv = quantize(rip[this->v, this->vec]);
	if (this->d > 5000)
		printf("%Y RINVIO LUNGO VP%d vett=%#x %d us (rinviato %d volte)\n",
		    walltimestamp, this->v, this->vec, this->d, rip[this->v, this->vec]);
	aperto[this->v, this->vec] = 0;
	rip[this->v, this->vec] = 0;
	this->t = 0;
}

tick-60s
{
	printf("=== %d min %Y\n", (timestamp - t0) / 60000000000, walltimestamp);
	printa("  %-40s %@d\n", @n);
	printa("  rinvii tipo %d : %@d\n", @kind);
	printa("  immexit op=%d kind=%d : %@d\n", @imm);
	printa("  intervalli aperti %@d", @aperti); printa("  chiusi %@d", @chiusi);
	printa("  latenza max %@d us\n", @latmax);
}
tick-10min
{
	printa("  latenza per intervallo (us): %@d\n", @lat);
	printa("  rinvii ripetuti per intervallo: %@d\n", @rinv);
}
