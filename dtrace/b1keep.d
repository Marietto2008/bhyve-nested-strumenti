#pragma D option quiet
#pragma D option switchrate=1hz
/*
 * Claude 21/10/2026 -- B1 (parere #28 di Astra): la conservazione e' davvero
 * esercitata? Per ogni INVEPT con hw.vmm.vmx.vept_keep=1 la sonda veptkeep
 * dice foglie vive prima, foglie invalidate, intervalli, voci cambiate,
 * motivi di svuotamento (0 = radice conservata), tabelle tracciate, ns.
 * Con shadow_fill (foglie installate) e invept: EPT violation per INVEPT.
 * Riepilogo al minuto e alla fine (dtrace -s b1keep.d, kill -INT o fine).
 */
vmm:vmx:nested:veptkeep
{
	this->live = arg2; this->inv = arg3;
	this->nr = arg4 & 0xffffffff; this->nc = arg4 >> 32;
	this->fb = arg5 & 0xffff; this->trk = (arg5 >> 16) & 0xffff;
	this->ns = arg5 >> 32;
	this->kept = this->fb == 0;
	@m["a INVEPT su radici (B1)"] = sum(1); @t["a INVEPT su radici (B1)"] = sum(1);
	@m["b   radice conservata"] = sum(this->kept); @t["b   radice conservata"] = sum(this->kept);
	@m["c   svuotamento completo"] = sum(!this->kept); @t["c   svuotamento completo"] = sum(!this->kept);
	@m["d foglie vive prima"] = sum(this->live); @t["d foglie vive prima"] = sum(this->live);
	@m["e foglie invalidate"] = sum(this->inv); @t["e foglie invalidate"] = sum(this->inv);
	@m["f foglie conservate"] = sum(this->live - this->inv); @t["f foglie conservate"] = sum(this->live - this->inv);
	@m["g voci EPT12 cambiate"] = sum(this->nc); @t["g voci EPT12 cambiate"] = sum(this->nc);
	@fb["tabella ambigua"] = sum((this->fb & 0x01) != 0);
	@fb["voce di PML4"] = sum((this->fb & 0x02) != 0);
	@fb["tetto tabelle"] = sum((this->fb & 0x04) != 0);
	@fb["illeggibile"] = sum((this->fb & 0x08) != 0);
	@fb["troppi intervalli"] = sum((this->fb & 0x20) != 0);
	@fb["corsa fra le passate"] = sum((this->fb & 0x40) != 0);
	@fb["non conservabile (MMIO/non wired)"] = sum((this->fb & 0x80) != 0);
	@fb["memoria"] = sum((this->fb & 0x100) != 0);
	@fb["walk su ambigua/PML4"] = sum((this->fb & 0x200) != 0);
	@fb["verifica HPA"] = sum((this->fb & 0x400) != 0);
	@qlive = quantize(this->live); @qinv = quantize(this->inv);
	@qkinv = quantize(this->kept ? this->inv : -1);
	@qtrk = quantize(this->trk); @qus = quantize(this->ns / 1000);
	/* il caso del parere #28 §5: una PTE su >= 1000 foglie */
	@one["INVEPT conservati con 1 voce cambiata"] = sum(this->kept && this->nc == 1);
	@one["  ...e 1 foglia invalidata"] = sum(this->kept && this->nc == 1 && this->inv == 1);
	@one["  ...con >= 1000 foglie vive"] = sum(this->kept && this->nc == 1 && this->inv == 1 && this->live >= 1000);
	@ep[(long)(arg1 & 0x000ffffffffff000)] = sum(1);
}
vmm:vmx:nested:shadow_fill
{
	@m["h foglie installate (EPT violation risolte)"] = sum(1);
	@t["h foglie installate (EPT violation risolte)"] = sum(1);
}
vmm:vmx:nested:invept
{
	@m["i INVEPT dell'L1"] = sum(1); @t["i INVEPT dell'L1"] = sum(1);
}
vmm:vmx:nested:veptmemgen
{
	printf("%Y veptmemgen vcpu%d generazione %d radici svuotate %d\n",
	    walltimestamp, arg0, arg1, arg2);
}
vmm:vmx:nested:veptverify
{
	printf("%Y VERIFICA DISCORDE vcpu%d l2gpa %#lx foglia %#lx attesa %#lx r=%d\n",
	    walltimestamp, arg0, arg1, arg2, arg3, (int)arg4);
}
tick-60s
{
	printf("=== %Y\n", walltimestamp);
	printa("  %-44s %@d\n", @m); clear(@m);
}
END
{
	printf("##### totale %Y\n", walltimestamp);
	printa("  %-44s %@d\n", @t);
	printa("  svuotamento per %-34s %@d\n", @fb);
	printa("  %-44s %@d\n", @one);
	printa("  EPTP12 %#lx : %@d INVEPT\n", @ep);
	printa("  foglie vive per INVEPT: %@d\n", @qlive);
	printa("  foglie invalidate per INVEPT: %@d\n", @qinv);
	printa("  foglie invalidate negli INVEPT conservati (-1 = svuotati): %@d\n", @qkinv);
	printa("  tabelle tracciate per INVEPT: %@d\n", @qtrk);
	printa("  costo dell'INVEPT B1 (us): %@d\n", @qus);
}
