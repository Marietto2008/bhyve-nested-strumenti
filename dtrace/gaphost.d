#pragma D option quiet
#pragma D option switchrate=4hz
/*
 * Claude 23/10/2026 -- parere #33 §3, timeline FreeBSD dei buchi di WSL2.
 *  - per vCPU: intervalli > 200 ms senza un ingresso in L2 (enter_l2), con l'ora
 *    di parete d'inizio e fine (si confronta con i BUCO di gapmon via SYNC);
 *  - thread vCPU di bhyve (nome "vcpu N") fuori CPU per > 100 ms (off-cpu -> on-cpu);
 *  - ogni minuto: ingressi in L2 per vCPU.
 * La vCPU e' quella di nested_enter_l2 (arg0 = struct vmx_vcpu *, vcpuid a +0x2c0).
 */
int64_t ultimo[int];
int64_t fuori[uintptr_t];

vmm:vmx:nested:enter_l2
{
	this->v = *(int *)(arg0 + 0x2c0);
	this->now = timestamp;
	@ent[this->v] = count();
}
vmm:vmx:nested:enter_l2 /ultimo[this->v] && this->now - ultimo[this->v] > 200000000/
{
	printf("L2-FERMA vcpu%d %d ms fino a %Y.%09d\n", this->v,
	    (this->now - ultimo[this->v]) / 1000000, walltimestamp,
	    walltimestamp % 1000000000);
}
vmm:vmx:nested:enter_l2 { ultimo[this->v] = this->now; }

sched:::off-cpu /execname == "bhyve" && strstr(stringof(curthread->td_name), "vcpu") != NULL/ { fuori[(uintptr_t)curthread] = timestamp; }
sched:::on-cpu /execname == "bhyve" && strstr(stringof(curthread->td_name), "vcpu") != NULL && fuori[(uintptr_t)curthread] && timestamp - fuori[(uintptr_t)curthread] > 100000000/
{
	printf("THREAD-FUORI tid %d %d ms fino a %Y.%09d\n", tid,
	    (timestamp - fuori[(uintptr_t)curthread]) / 1000000, walltimestamp,
	    walltimestamp % 1000000000);
}
sched:::on-cpu /execname == "bhyve"/ { fuori[(uintptr_t)curthread] = 0; }

tick-60s
{
	printf("=== %Y ingressi in L2 per vCPU\n", walltimestamp);
	printa("  vcpu%d %@d\n", @ent); trunc(@ent);
}
