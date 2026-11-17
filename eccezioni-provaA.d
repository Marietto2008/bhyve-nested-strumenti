#!/usr/sbin/dtrace -qs
/*
 * eccezioni-provaA.d -- claude 15/11/2026 (prova A): con hw.vmm.trace_guest_exceptions=1 ogni eccezione del guest esce
 * verso L0 e passa da vmm:vmx:exit:exception (vmx, vcpuid, vm_exit *, vettore, errcode) prima di essere riflessa.
 * RIP da struct vm_exit (offset 8). Stampa: tutte quelle del thread «CPU 1/Bhyve» e quelle di qualsiasi vCPU con RIP
 * sotto 1 MB (trampolino d'avvio degli AP); conteggi per thread e vettore ogni 30 s. Senza -p.
 */
BEGIN { n = 0; printf("%Y eccezioni-provaA avviato\n", walltimestamp); }
vmm:vmx:exit:exception
{
	@cnt[stringof(curthread->td_name), (int)arg3] = count();
	this->rip = *(uint64_t *)(arg2 + 8);
}
vmm:vmx:exit:exception
/ n < 4000 && (stringof(curthread->td_name) == "CPU 1/Bhyve" || this->rip < 0x100000) /
{
	n++;
	printf("%Y %s vettore %2d errcode %#6x RIP %#lx\n", walltimestamp, curthread->td_name, (int)arg3,
	    (uint32_t)arg4, this->rip);
}
tick-30s
{
	printf("%Y --- conteggi (righe %d)\n", walltimestamp, n);
	printa("  %-14s vettore %2d %@d\n", @cnt);
}
