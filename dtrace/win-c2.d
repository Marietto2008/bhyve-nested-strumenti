#pragma D option quiet
#pragma D option switchrate=1hz
/*
 * Claude 21/10/2026 -- C2 (parere #26 di Astra): simulazione di B1 a ogni INVEPT.
 * P_keep(a) = foglie vive conservate / vive, con QUALSIASI fallback = 0 conservate
 *             (disallineamento nei walk -> radice intera, scelta prudente);
 * P_keep(b) = idem ma il disallineamento nei walk non forza il fallback (B1 lo
 *             invaliderebbe per voce: le voci cambiate sono gia' negli intervalli).
 * Prima: sysctl hw.vmm.vmx.vept_diag=1.
 */
vmm:vmx:nested:veptdiag4
{
	this->live = arg1; this->hit = arg2; this->fb = (int)arg4;
	this->ka = this->fb != 0 ? 0 : this->live - this->hit;
	this->kb = (this->fb & ~0x10) != 0 ? 0 : this->live - this->hit;
	@m["a INVEPT"] = sum(1); @t["a INVEPT"] = sum(1);
	@m["b foglie vive"] = sum(this->live); @t["b foglie vive"] = sum(this->live);
	@m["c foglie colpite dagli intervalli"] = sum(this->hit); @t["c foglie colpite dagli intervalli"] = sum(this->hit);
	@m["d conservate (a, walk->radice)"] = sum(this->ka); @t["d conservate (a, walk->radice)"] = sum(this->ka);
	@m["e conservate (b, walk per voce)"] = sum(this->kb); @t["e conservate (b, walk per voce)"] = sum(this->kb);
	@m["f INVEPT con fallback (a)"] = sum(this->fb != 0); @t["f INVEPT con fallback (a)"] = sum(this->fb != 0);
	@m["g INVEPT con fallback (b)"] = sum((this->fb & ~0x10) != 0); @t["g INVEPT con fallback (b)"] = sum((this->fb & ~0x10) != 0);
	@fb["ambigua"] = sum((this->fb & 0x01) != 0); @fb["livello 3"] = sum((this->fb & 0x02) != 0);
	@fb["tetto"] = sum((this->fb & 0x04) != 0); @fb["illeggibile"] = sum((this->fb & 0x08) != 0);
	@fb["walk"] = sum((this->fb & 0x10) != 0); @fb["troppi intervalli"] = sum((this->fb & 0x20) != 0);
	@nr = quantize((int)arg3); @ns = quantize(arg5 / 1000);
	@colp = quantize(this->hit);
}
/* C2.1: tabelle distinte cumulative per EPTP12 (veptdiag5, al massimo 1/s) */
vmm:vmx:nested:veptdiag5
{
	this->ep = (long)(arg1 & 0x000ffffffffff000);
	@d1[this->ep] = max(arg2 & 0x1fffff); @d10[this->ep] = max((arg2 >> 21) & 0x1fffff);
	@d60[this->ep] = max((arg2 >> 42) & 0x1fffff); @dtot[this->ep] = max(arg3);
	@reuse[this->ep] = max(arg4); @trk[this->ep] = max(arg5);
	@D1[this->ep] = max(arg2 & 0x1fffff); @D10[this->ep] = max((arg2 >> 21) & 0x1fffff);
	@D60[this->ep] = max((arg2 >> 42) & 0x1fffff); @DTOT[this->ep] = max(arg3);
	@REUSE[this->ep] = max(arg4); @TRK[this->ep] = max(arg5);
}
tick-60s
{
	printf("=== %Y\n", walltimestamp);
	printa("  %-36s %@d\n", @m); clear(@m);
	printa("  EPTP12 %#lx distinte 1s=%@d 10s=%@d 60s=%@d totali=%@d riusi=%@d tracciate=%@d\n",
	    @d1, @d10, @d60, @dtot, @reuse, @trk);
	trunc(@d1); trunc(@d10); trunc(@d60); trunc(@dtot); trunc(@reuse); trunc(@trk);
}
tick-10min
{
	printf("##### cumulativo %Y\n", walltimestamp);
	printa("  %-36s %@d\n", @t);
	printa("  motivo di fallback %-18s : %@d INVEPT\n", @fb);
	printa("  intervalli (uniti) per INVEPT: %@d\n", @nr);
	printa("  foglie colpite per INVEPT: %@d\n", @colp);
	printa("  costo del conteggio (us): %@d\n", @ns);
	printa("  MAX EPTP12 %#lx: distinte 1s %@d 10s %@d 60s %@d totali %@d riusi %@d tracciate %@d\n",
	    @D1, @D10, @D60, @DTOT, @REUSE, @TRK);
}
