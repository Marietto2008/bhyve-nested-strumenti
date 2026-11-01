#pragma D option quiet
#pragma D option switchrate=1hz
/*
 * Claude 22/10/2026 -- parere #29 di Astra: §4 INVEPT dell'L1 per RIP (dove
 * Hyper-V li esegue) e per tipo, al minuto; §8 ogni cambio della generazione
 * dei mapping di L0 con chi lo fa (stack del kernel e processo).
 */
vmm:vmx:nested:invept2
{
	@m[arg1, (int)arg3] = count(); @t[arg1, (int)arg3] = count();
	@kept["radici conservate"] = sum((arg5 >> 16) & 0xffff);
	@kept["radici svuotate"] = sum(arg5 & 0xffff);
}
/*
 * Parere #33 §4: INVEPT per vCPU dell'L1 e per EPTP12 corrente (R2 = INVEPT / VP),
 * e §2: durata del gestore (vmx_vept_invept) in us, distribuzione e massimo.
 */
vmm:vmx:nested:invept2
{
	@vp[arg0] = count(); @VP[arg0] = count();
	@vpep[arg0, arg2] = count();
}
fbt::vmx_vept_invept:entry { self->tinv = timestamp; }
fbt::vmx_vept_invept:return /self->tinv/
{
	this->us = (timestamp - self->tinv) / 1000;
	@lat = quantize(this->us); @latmax = max(this->us); @latsum = sum(this->us); @latn = count();
	self->tinv = 0;
}

vmm:mem:memmap:gen
{
	printf("%Y memmap gen op=%d gpa=%#lx len=%#lx segid=%d flags=%#x gen=%d %s\n",
	    walltimestamp, arg0, arg1, arg2, (int)arg3, (int)arg4, arg5, execname);
	stack(12);
}
tick-60s
{
	printf("=== %Y INVEPT per RIP, tipo\n", walltimestamp);
	printa("  INVEPT vCPU %d (minuto) : %@d\n", @vp); trunc(@vp);
	printa("  rip %#lx tipo %d : %@d\n", @m); trunc(@m);
}
tick-10min
{
	printf("##### cumulativo %Y\n", walltimestamp);
	printa("  INVEPT vCPU %d : %@d\n", @VP);
	printa("  durata gestore INVEPT (us): %@d\n", @lat);
	printa("  durata gestore INVEPT max %@d us\n", @latmax);
	printa("  durata gestore INVEPT somma %@d us\n", @latsum);
	printa("  durata gestore INVEPT n %@d\n", @latn);
	printa("  vCPU %d VMCS12 %#lx : %@d INVEPT\n", @vpep);
	printa("  rip %#lx tipo %d : %@d\n", @t);
	printa("  %s : %@d\n", @kept);
}
END
{
	printf("##### totale per RIP, tipo\n");
	printa("  rip %#lx tipo %d : %@d\n", @t);
	printa("  %s : %@d\n", @kept);
}
