#!/usr/sbin/dtrace -qs
/*
 * Chi consegna il #PF al guest FreeBSD (L2)? Coglie gli ingressi in L2 in cui
 * l'L1 (Hyper-V) chiede nel VMCS12 l'iniezione di un #PF (info valida, tipo 3,
 * vettore 14), con l'ultima EPT violation riflessa all'L1 dallo stesso thread
 * (= stesso vCPU). Nessuna modifica al modulo, nessun -p.
 */
vmm:vmx:nested:veptrefl
{
	self->vid = arg0; self->eptp = arg1; self->gpa = arg2;
	self->qual = arg3; self->r = arg4; self->t = timestamp;
	@refl[arg1] = count();
}

vmm:vmx:nested:compose
/(arg1 & 0x800007ff) == 0x8000030e/
{
	printf("%Y vcpu%d L1 INIETTA #PF info=%x rflags=%x intr=%x | ultima veptrefl: eptp12=%x gpa=%x qual=%x esito=%d, %d us prima\n",
	    walltimestamp, self->vid, arg1, arg4 >> 32, arg4 & 0xffffffff,
	    self->eptp, self->gpa, self->qual, self->r,
	    self->t ? (timestamp - self->t) / 1000 : -1);
	@inj[self->eptp] = count();
}

vmm:vmx:nested:compose
/(arg1 & 0x80000000) && (arg1 & 0x700) == 0x300/
{
	@exc[arg1 & 0xff] = count();
}

tick-60s
{
	printf("%Y riepilogo: eccezioni hw iniettate dall'L1 per vettore\n", walltimestamp);
	printa("  vettore %d: %@d\n", @exc);
	printa("  #PF iniettati, eptp12 %x: %@d\n", @inj);
}
