#pragma D option quiet
#pragma D option switchrate=4hz
#pragma D option aggrate=4hz
#pragma D option dynvarsize=16m
#pragma D option nspec=64
#pragma D option specsize=256k
#pragma D option bufsize=8m
/*
 * Claude 24/10/2026 -- parere #38 (pmap) §3/§4/§7: seconda sonda leggera sui gestori
 * INVEPT. Rispetto a invB.d:
 *  - attesa attiva sui mutex SOMMATA IN NANOSECONDI (prima arg1/1000 per evento azzerava
 *    ogni attesa sotto il microsecondo), per indirizzo e nome del lock, con conteggio,
 *    media e distribuzione; la stessa misura per i thread vCPU FUORI dai gestori, per
 *    confronto;
 *  - stack delle attese attive su "pmap" dentro i gestori, campionati (~1 su 64, bit
 *    bassi del timestamp), aggregati in memoria;
 *  - per ogni uscita dalla CPU dentro un gestore: il thread che SUBENTRA (arg0 di
 *    sched:::off-cpu e' il nuovo thread su FreeBSD): processo, nome, tid, priorita';
 *    e la priorita' del thread vCPU che esce. Riga stampata (speculazione) solo se la
 *    sospensione supera 0,5 ms; aggregato per tutte.
 * Il thread entrante e' il vincitore dello scheduler, non necessariamente chi ha mandato
 * l'IPI.
 */
fbt::vmx_vept_invept:entry
{
	self->in = 1; self->isv = 1;
	self->t0 = timestamp; self->v0 = vtimestamp;
	self->n = 0; self->off = 0; self->toff = 0;
}

sched:::off-cpu /self->in/
{
	self->toff = timestamp;
	self->nxt = arg0;
	self->spec = speculation();
	@chi[stringof(((struct thread *)arg0)->td_proc->p_comm),
	    stringof(((struct thread *)arg0)->td_name)] = count();
	@prio_entrante = quantize(((struct thread *)arg0)->td_priority);
	@prio_uscente = quantize(curthread->td_priority);
}
sched:::off-cpu /self->in && self->spec/
{
	speculate(self->spec);
	printf("  SOSP %Y cpu %d tid %d prio %d -> %s/%s tid %d pid %d prio %d\n",
	    walltimestamp, cpu, tid, curthread->td_priority,
	    stringof(((struct thread *)arg0)->td_proc->p_comm),
	    stringof(((struct thread *)arg0)->td_name),
	    ((struct thread *)arg0)->td_tid,
	    ((struct thread *)arg0)->td_proc->p_pid,
	    ((struct thread *)arg0)->td_priority);
}
sched:::on-cpu /self->in && self->toff/
{
	self->d = timestamp - self->toff;
	self->n++; self->off += self->d;
	@sosp_us = quantize(self->d / 1000);
	@chi_us[stringof(((struct thread *)self->nxt)->td_proc->p_comm),
	    stringof(((struct thread *)self->nxt)->td_name)] = sum(self->d / 1000);
}
sched:::on-cpu /self->in && self->toff && self->spec && self->d > 500000/
{
	speculate(self->spec);
	printf("    durata %d us\n", self->d / 1000);
}
sched:::on-cpu /self->in && self->toff && self->spec && self->d > 500000/
{
	commit(self->spec); self->spec = 0;
}
sched:::on-cpu /self->in && self->toff && self->spec/
{
	discard(self->spec); self->spec = 0;
}
sched:::on-cpu /self->in/ { self->toff = 0; }

lockstat:::adaptive-spin /self->in/
{
	@spin_ns[arg0, stringof(((struct lock_object *)arg0)->lo_name)] = sum(arg1);
	@spin_n[arg0, stringof(((struct lock_object *)arg0)->lo_name)] = count();
	@spin_avg[arg0, stringof(((struct lock_object *)arg0)->lo_name)] = avg(arg1);
}
lockstat:::adaptive-spin /self->in && stringof(((struct lock_object *)arg0)->lo_name) == "pmap"/
{
	@spin_q = quantize(arg1);
}
lockstat:::adaptive-spin
/self->in && (timestamp & 0x3f) == 0 && stringof(((struct lock_object *)arg0)->lo_name) == "pmap"/
{
	@spin_stack[stack(10)] = count();
}
lockstat:::adaptive-spin /self->isv && !self->in/
{
	@spin_fuori_ns[stringof(((struct lock_object *)arg0)->lo_name)] = sum(arg1);
	@spin_fuori_n[stringof(((struct lock_object *)arg0)->lo_name)] = count();
}
lockstat:::adaptive-block /self->in/
{
	@blk_ns[arg0, stringof(((struct lock_object *)arg0)->lo_name)] = sum(arg1);
	@blk_n[arg0, stringof(((struct lock_object *)arg0)->lo_name)] = count();
}

fbt::vmx_vept_invept:return /self->in/
{
	this->wall = timestamp - self->t0;
	this->cpu = vtimestamp - self->v0;
	@W = quantize(this->wall / 1000); @C = quantize(this->cpu / 1000);
	@cpu_tot_ns = sum(this->cpu);
	@tot = count(); @sospesi = sum(self->n > 0);
	@oltre4 = sum(this->wall > 4000000); @oltre4cpu = sum(this->cpu > 4000000);
}
fbt::vmx_vept_invept:return /self->in && self->off > 500000/
{
	printf("INVEPT-SOSPESO %Y tid %d reale %d us cpu %d us sospensioni %d per %d us\n",
	    walltimestamp, tid, this->wall / 1000, this->cpu / 1000, self->n,
	    self->off / 1000);
}
fbt::vmx_vept_invept:return /self->in/ { self->in = 0; }

tick-10min
{
	printf("##### cumulativo %Y\n", walltimestamp);
	printa("  gestori %@d, con sospensioni %@d, reale>4ms %@d, cpu>4ms %@d, cpu totale %@d ns\n",
	    @tot, @sospesi, @oltre4, @oltre4cpu, @cpu_tot_ns);
	printf("  tempo REALE (us):"); printa(@W);
	printf("  tempo SULLA CPU (us):"); printa(@C);
	printf("  durata delle sospensioni (us):"); printa(@sosp_us);
	printf("  thread entranti (volte):\n"); printa("    %-16s %-24s %@d\n", @chi);
	printf("  thread entranti (us di sospensione del vCPU):\n"); printa("    %-16s %-24s %@d\n", @chi_us);
	printf("  priorita' entrante:"); printa(@prio_entrante);
	printf("  priorita' uscente (vCPU):"); printa(@prio_uscente);
	printf("  attesa attiva DENTRO i gestori (lock, nome, ns, volte, media ns):\n");
	printa("    %p %-20s %@d ns %@d %@d\n", @spin_ns, @spin_n, @spin_avg);
	printf("  attesa attiva su pmap, distribuzione (ns):"); printa(@spin_q);
	printf("  blocchi DENTRO i gestori (lock, nome, ns, volte):\n");
	printa("    %p %-20s %@d ns %@d\n", @blk_ns, @blk_n);
	printf("  attesa attiva dei vCPU FUORI dai gestori (nome, ns, volte):\n");
	printa("    %-20s %@d ns %@d\n", @spin_fuori_ns, @spin_fuori_n);
	printf("  stack campionati (~1/64) delle attese su pmap:\n");
	trunc(@spin_stack, 12); printa(@spin_stack);
}
