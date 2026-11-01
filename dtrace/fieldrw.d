#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option aggrate=50hz
#pragma D option bufsize=16m
/*
 * Claude 24/10/2026 -- parere #43 §3: VMREAD/VMWRITE dell'L1 per CAMPO VMCS (encoding), per
 * scegliere i campi dello shadow VMCS. Sonda passiva, senza stack.
 * Percorso: ogni VMREAD/VMWRITE dell'L1 esce da vmx_run e arriva a vmx_nested_exit (slow path,
 * vCPU FROZEN); nested_vmread/nested_vmwrite (inline) validano il campo con
 * nested_field_ok -> vm_get_register(vcpu, VMCS_IDENT(field)), cioe' un ident NEGATIVO
 * (bit 31) che contiene l'encoding: la PRIMA chiamata di questo tipo dentro vmx_nested_exit
 * e' il campo dell'istruzione. Motivo d'uscita: vmx_vcpu.vcpu (+8) -> struct vcpu.exitinfo
 * (+136) -> u.vmx.exit_reason (+20). In piu', per motivo, il tempo CPU passato in
 * vmx_nested_exit (vtimestamp: esclude le sonde) -- NON comprende l'uscita da vmx_run e il
 * rientro, che si stimano a parte.
 * Ogni 1 s: per motivo (23 VMREAD, 25 VMWRITE) e campo il conteggio; ogni 100 ms i totali.
 */
fbt::vmx_nested_exit:entry
{
	self->in = 1; self->got = 0;
	self->r = *(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 136 + 20) & 0xffff;
	self->vt = vtimestamp;
}
fbt::vm_get_register:entry /self->in && !self->got && (int)arg1 < 0/
{
	self->got = 1;
	@f[self->r, arg1 & 0x7fffffff] = count();
}
fbt::vmx_nested_exit:return /self->in/
{
	@n[self->r] = count();
	@t[self->r] = sum(vtimestamp - self->vt);
	self->in = 0; self->got = 0;
}
tick-100ms
{
	printf("T %d\n", walltimestamp);
	printa("  n %d %@d %@d\n", @n, @t);
	trunc(@n); trunc(@t);
}
tick-1s
{
	printf("S %d\n", walltimestamp);
	printa("  f %d %#x %@d\n", @f);
	trunc(@f);
}
