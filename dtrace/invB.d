#pragma D option quiet
#pragma D option switchrate=4hz
#pragma D option dynvarsize=16m
#pragma D option nspec=64
#pragma D option specsize=256k
#pragma D option bufsize=8m
/*
 * Claude 23/10/2026 -- parere #37 §3: la famiglia B dei gestori INVEPT (sospensioni
 * dentro vmx_vept_invept). Sonda LEGGERA: niente fbt su vm_gpa_hold ne' su
 * vept_zap_range; solo entry/return del gestore piu' sonde che scattano quando il thread
 * lascia la CPU o un lock e' conteso.
 *  - per ogni sospensione dentro il gestore: motivo (sched:::preempt = prelazione,
 *    sched:::sleep = sleep volontario, nessuno dei due = altro, per esempio blocco su
 *    turnstile), td_wmesg, td_lockname, stack(12) all'uscita dalla CPU; il tutto si
 *    stampa (speculazione) solo se la sospensione supera 0,5 ms, con la sua durata;
 *  - lockstat dentro il gestore: blocchi (adaptive/rw/sx-block) e attese attive
 *    (adaptive-spin, rw/sx-spin) per nome del lock, tempo e conteggio;
 *  - per ogni gestore con almeno una sospensione: vCPU, EPTP12, reale, sulla CPU,
 *    numero e somma delle sospensioni;
 *  - ogni 10 minuti: distribuzioni di tempo reale e sulla CPU di TUTTI i gestori (con
 *    questa sonda leggera vtimestamp ~ costo vero) e il riepilogo lockstat.
 */
fbt::vmx_vept_invept:entry
{
	self->in = 1;
	self->t0 = timestamp; self->v0 = vtimestamp;
	self->n = 0; self->off = 0; self->why = 0; self->toff = 0;
	self->kv = -1; self->kep = (uint64_t)0;
}
vmm:vmx:nested:veptkeep /self->in/ { self->kv = arg0; self->kep = arg1; }

sched:::preempt /self->in/ { self->why = 1; }
sched:::sleep /self->in/ { self->why = 2; }

sched:::off-cpu /self->in/
{
	self->toff = timestamp;
	self->spec = speculation();
}
sched:::off-cpu /self->in && self->spec/
{
	speculate(self->spec);
	printf("  SOSP %Y vcpu%d tid %d motivo %s wmesg %s lock %s\n", walltimestamp,
	    (int)self->kv, tid,
	    self->why == 1 ? "PRELAZIONE" : self->why == 2 ? "SLEEP" : "altro",
	    curthread->td_wmesg != NULL ? stringof(curthread->td_wmesg) : "-",
	    curthread->td_lockname != NULL ? stringof(curthread->td_lockname) : "-");
	stack(12);
}
sched:::off-cpu /self->in/
{
	@motivo[self->why == 1 ? "PRELAZIONE" : self->why == 2 ? "SLEEP" : "altro",
	    curthread->td_wmesg != NULL ? stringof(curthread->td_wmesg) : "-",
	    curthread->td_lockname != NULL ? stringof(curthread->td_lockname) : "-"] = count();
	self->why = 0;
}

sched:::on-cpu /self->in && self->toff/
{
	self->d = timestamp - self->toff;
	self->n++; self->off += self->d;
	@sosp_us = quantize(self->d / 1000);
}
sched:::on-cpu /self->in && self->toff && self->spec && self->d > 500000/
{
	speculate(self->spec);
	printf("    durata %d us\n", self->d / 1000);
}
sched:::on-cpu /self->in && self->toff && self->spec && self->d > 500000/
{
	commit(self->spec);
	self->spec = 0;
}
sched:::on-cpu /self->in && self->toff && self->spec/
{
	discard(self->spec);
	self->spec = 0;
}
sched:::on-cpu /self->in/ { self->toff = 0; }

lockstat:::adaptive-block, lockstat:::rw-block, lockstat:::sx-block /self->in/
{
	@lkb[probename, stringof(((struct lock_object *)arg0)->lo_name)] = sum(arg1 / 1000);
	@lkbn[probename, stringof(((struct lock_object *)arg0)->lo_name)] = count();
}
lockstat:::adaptive-spin, lockstat:::rw-spin, lockstat:::sx-spin /self->in/
{
	@lks[probename, stringof(((struct lock_object *)arg0)->lo_name)] = sum(arg1 / 1000);
	@lksn[probename, stringof(((struct lock_object *)arg0)->lo_name)] = count();
}

fbt::vmx_vept_invept:return /self->in/
{
	this->wall = timestamp - self->t0;
	this->cpu = vtimestamp - self->v0;
	@W = quantize(this->wall / 1000); @C = quantize(this->cpu / 1000);
	@tot = count(); @sospesi = sum(self->n > 0);
	@oltre4 = sum(this->wall > 4000000); @oltre4cpu = sum(this->cpu > 4000000);
}
fbt::vmx_vept_invept:return /self->in && self->n > 0/
{
	printf("INVEPT-SOSPESO %Y vcpu%d tid %d eptp12 %#lx reale %d us cpu %d us sospensioni %d per %d us\n",
	    walltimestamp, (int)self->kv, tid, self->kep, this->wall / 1000,
	    this->cpu / 1000, self->n, self->off / 1000);
}
fbt::vmx_vept_invept:return /self->in/ { self->in = 0; }

tick-10min
{
	printf("##### cumulativo %Y\n", walltimestamp);
	printa("  gestori %@d, con sospensioni %@d, reale>4ms %@d, cpu>4ms %@d\n",
	    @tot, @sospesi, @oltre4, @oltre4cpu);
	printf("  tempo REALE (us):"); printa(@W);
	printf("  tempo SULLA CPU (us):"); printa(@C);
	printf("  durata delle sospensioni (us):"); printa(@sosp_us);
	printf("  sospensioni per motivo / wmesg / lock:\n");
	printa("    %-10s %-16s %-24s %@d\n", @motivo);
	printf("  lockstat blocchi (us, volte):\n");
	printa("    %-14s %-28s %@d us %@d\n", @lkb, @lkbn);
	printf("  lockstat attese attive (us, volte):\n");
	printa("    %-14s %-28s %@d us %@d\n", @lks, @lksn);
}
