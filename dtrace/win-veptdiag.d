#pragma D option quiet
#pragma D option switchrate=1hz
/*
 * Claude 21/10/2026 -- fase C (parere #25 di Astra): per ogni INVEPT che colpisce
 * una radice shadow, quante tabelle EPT12 tracciate sono cambiate rispetto alla
 * fotografia presa quando sono state usate. Prima: sysctl hw.vmm.vmx.vept_diag=1.
 * P0 = INVEPT senza alcuna modifica (ne' alla scansione ne' durante i walk, senza
 * tabelle illeggibili ne' tetto superato) / INVEPT esaminati.
 * Riepilogo per minuto (per separare l'avvio della partizione WSL dal carico
 * stabile) e cumulativo ogni 10 minuti.
 */
int64_t t0;
BEGIN { t0 = timestamp; }

vmm:vmx:nested:veptdiag
{
	self->tr = (int)arg2; self->tch = (int)arg3; self->ech = (int)arg4;
	self->ns = arg5; self->ep = arg1;
}
vmm:vmx:nested:veptdiag2
{
	this->lv = arg1; this->k = arg2; this->wm = arg3;
	this->unr = (int)(arg4 & 0xffffffff); this->ov = (int)(arg4 >> 32);
	this->pulito = self->tch == 0 && this->wm == 0 && this->unr == 0 && this->ov == 0;
	@m["INVEPT esaminati"] = sum(1); @t["INVEPT esaminati"] = sum(1);
	@m["INVEPT senza modifiche (P0)"] = sum(this->pulito); @t["INVEPT senza modifiche (P0)"] = sum(this->pulito);
	@m["  con tabelle cambiate"] = sum(self->tch != 0); @t["  con tabelle cambiate"] = sum(self->tch != 0);
	@m["  con disallineamenti nei walk"] = sum(this->wm != 0); @t["  con disallineamenti nei walk"] = sum(this->wm != 0);
	@m["  con tetto superato"] = sum(this->ov); @t["  con tetto superato"] = sum(this->ov);
	@m["  con tabelle illeggibili"] = sum(this->unr != 0); @t["  con tabelle illeggibili"] = sum(this->unr != 0);
	@tracc = quantize(self->tr); @tcamb = quantize(self->tch); @ecamb = quantize(self->ech);
	@wmis = quantize(this->wm); @scan = quantize(self->ns / 1000);
	@lev[0] = sum(this->lv & 0xffff); @lev[1] = sum((this->lv >> 16) & 0xffff);
	@lev[2] = sum((this->lv >> 32) & 0xffff); @lev[3] = sum((this->lv >> 48) & 0xffff);
	@kind["indirizzo"] = sum(this->k & 0x3ff); @kind["permessi"] = sum((this->k >> 10) & 0x3ff);
	@kind["page size"] = sum((this->k >> 20) & 0x3ff); @kind["attributi"] = sum((this->k >> 30) & 0x3ff);
	@kind["accessed/dirty"] = sum((this->k >> 40) & 0x3ff); @kind["altro"] = sum((this->k >> 50) & 0x3ff);
	@ept[(long)(self->ep & 0x000ffffffffff000)] = count();
	self->pulito = this->pulito;
}
/* traduzioni shadow vive all'INVEPT, e quante B0 ne conserverebbe */
vmm:vmx:nested:veptdiag3
{
	@m["traduzioni vive (somma)"] = sum(arg1); @t["traduzioni vive (somma)"] = sum(arg1);
	@m["traduzioni conservabili da B0"] = sum(self->pulito ? arg1 : 0);
	@t["traduzioni conservabili da B0"] = sum(self->pulito ? arg1 : 0);
	@vive = quantize(arg1);
}

tick-60s
{
	printf("=== %d min %Y\n", (timestamp - t0) / 60000000000, walltimestamp);
	printa("  %-36s %@d\n", @m); clear(@m);
}
tick-10min
{
	printf("##### cumulativo a %d min\n", (timestamp - t0) / 60000000000);
	printa("  %-36s %@d\n", @t);
	printa("  voci cambiate al livello %d : %@d\n", @lev);
	printa("  voci cambiate per tipo %-16s : %@d\n", @kind);
	printa("  EPTP12 %#lx : %@d INVEPT\n", @ept);
	printa("  tabelle tracciate per INVEPT: %@d\n", @tracc);
	printa("  tabelle cambiate per INVEPT: %@d\n", @tcamb);
	printa("  voci cambiate per INVEPT: %@d\n", @ecamb);
	printa("  disallineamenti nei walk per INVEPT: %@d\n", @wmis);
	printa("  tempo di scansione (us): %@d\n", @scan);
	printa("  traduzioni vive per INVEPT: %@d\n", @vive);
}
