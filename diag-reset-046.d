#!/usr/sbin/dtrace -qs
/*
 * diag-reset-046.d -- claude 15/11/2026 (diagnosi Fable 046 §3): eventi iniettati nei vCPU di QEMU durante un riavvio
 * sul posto. Solo sonde fbt su argomenti scalari (il modulo non porta il CTF delle sue strutture). Senza -p.
 *   vm_inject_exception(vcpu, vector, errcode_valid, errcode, restart)
 *   vm_inject_nmi(vcpu), vm_inject_extint(vcpu)
 *   vm_exit_intinfo(vcpu, info): evento in consegna salvato all'uscita (bit 31 = valido)
 * Ogni riga: ora, thread («CPU n/Bhyve» con -name debug-threads=on), evento. Le prime 3000 righe, poi solo i conteggi
 * (stampati ogni 10 s e alla fine).
 */
BEGIN { righe = 0; printf("%Y diag-reset-046 avviato\n", walltimestamp); }

fbt::vm_inject_exception:entry /strstr(execname, "qemu") != NULL/
{
	@ecc[curthread->td_name, arg1] = count();
}
fbt::vm_inject_exception:entry /strstr(execname, "qemu") != NULL && righe < 3000/
{
	righe++;
	printf("%Y %s ECCEZIONE vettore %d errcode_valido %d errcode %#x restart %d\n", walltimestamp,
	    curthread->td_name, (int)arg1, (int)arg2, (uint32_t)arg3, (int)arg4);
}
fbt::vm_inject_nmi:entry /strstr(execname, "qemu") != NULL/
{
	@nmi[curthread->td_name] = count();
}
fbt::vm_inject_nmi:entry /strstr(execname, "qemu") != NULL && righe < 3000/
{
	righe++;
	printf("%Y %s NMI\n", walltimestamp, curthread->td_name);
}
fbt::vm_inject_extint:entry /strstr(execname, "qemu") != NULL/
{
	@extint[curthread->td_name] = count();
}
fbt::vm_exit_intinfo:entry /strstr(execname, "qemu") != NULL && (arg1 & 0x80000000)/
{
	@intinfo[curthread->td_name, (arg1 >> 8) & 7, arg1 & 0xff] = count();
}
fbt::vm_exit_intinfo:entry /strstr(execname, "qemu") != NULL && (arg1 & 0x80000000) && righe < 3000/
{
	righe++;
	printf("%Y %s INTINFO tipo %d vettore %d info %#lx\n", walltimestamp, curthread->td_name,
	    (int)((arg1 >> 8) & 7), (int)(arg1 & 0xff), arg1);
}
tick-10s
{
	printf("%Y --- conteggi (righe stampate %d)\n", walltimestamp, righe);
	printa("  eccezione  %-14s vettore %3d  %@d\n", @ecc);
	printa("  nmi        %-14s %@d\n", @nmi);
	printa("  extint     %-14s %@d\n", @extint);
	printa("  intinfo    %-14s tipo %d vettore %3d  %@d\n", @intinfo);
}
