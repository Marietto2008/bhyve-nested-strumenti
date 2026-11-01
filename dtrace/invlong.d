#pragma D option quiet
#pragma D option switchrate=2hz
#pragma D option dynvarsize=16m
/*
 * Claude 23/10/2026 -- parere #34 §2: dove finisce il tempo dei gestori INVEPT lunghi.
 * Per ogni chiamata di vmx_vept_invept:
 *  - tempo reale (timestamp) e sulla CPU (vtimestamp); fuori CPU = differenza, piu'
 *    numero e massimo delle sospensioni (sched:::off-cpu / on-cpu dello stesso thread);
 *  - fasi: invalidazione parziale (vept_zap_range, solo la chiamata piu' esterna),
 *    svuotamento (vept_root_wipe), tabelle EPT12 lette (vm_gpa_hold);
 *  - dalla sonda veptkeep: vCPU, EPTP12, foglie vive prima e invalidate, voci
 *    cambiate, motivi di svuotamento (0 = radice conservata), tabelle tracciate.
 * Scansione ~= sulla CPU - parziale - svuotamento. Un record per ogni chiamata oltre
 * 4 ms; per tutte, distribuzioni (us) ogni 10 minuti.
 */
fbt::vmx_vept_invept:entry
{
	self->in = 1;
	self->t0 = timestamp; self->v0 = vtimestamp;
	self->offn = 0; self->offt = 0; self->offmax = 0; self->toff = 0;
	self->holds = 0; self->zd = 0; self->zap = 0; self->wipe = 0;
	self->kv = -1; self->kep = (uint64_t)0; self->klive = (uint64_t)0; self->kinv = (uint64_t)0; self->knc = (uint64_t)0;
	self->kfb = (uint64_t)0xffff; self->kntr = (uint64_t)0; self->kns = (uint64_t)0;
}
sched:::off-cpu /self->in/ { self->toff = timestamp; }
sched:::on-cpu /self->in && self->toff/
{
	this->d = timestamp - self->toff;
	self->offn++; self->offt += this->d;
	self->offmax = this->d > self->offmax ? this->d : self->offmax;
	self->toff = 0;
}
fbt::vm_gpa_hold:entry /self->in/ { self->holds++; }
fbt::vept_zap_range:entry /self->in && self->zd == 0/ { self->zs = timestamp; }
fbt::vept_zap_range:entry /self->in/ { self->zd++; }
fbt::vept_zap_range:return /self->in/ { self->zd--; }
fbt::vept_zap_range:return /self->in && self->zd == 0/ { self->zap += timestamp - self->zs; }
fbt::vept_root_wipe:entry /self->in/ { self->ws = timestamp; }
fbt::vept_root_wipe:return /self->in && self->ws/ { self->wipe += timestamp - self->ws; self->ws = 0; }
vmm:vmx:nested:veptkeep /self->in/
{
	self->kv = arg0; self->kep = arg1; self->klive = arg2; self->kinv = arg3;
	self->knc = arg4 >> 32; self->kfb = arg5 & 0xffff;
	self->kntr = (arg5 >> 16) & 0xffff; self->kns = arg5 >> 32;
}
fbt::vmx_vept_invept:return /self->in/
{
	this->wall = timestamp - self->t0;
	this->cpu = vtimestamp - self->v0;
	@wall = quantize(this->wall / 1000); @oncpu = quantize(this->cpu / 1000);
	@W = quantize(this->wall / 1000); @C = quantize(this->cpu / 1000);
	@con_sosp = sum(self->offn > 0); @tot = count();
}
fbt::vmx_vept_invept:return /self->in && timestamp - self->t0 > 4000000/
{
	this->wall = timestamp - self->t0;
	this->cpu = vtimestamp - self->v0;
	printf("LUNGO %Y vcpu%d tid %d eptp12 %#lx reale %d us cpu %d us fuori %d us (%d sosp, max %d us) | scansione~%d us parziale %d us svuotamento %d us | tabelle lette %d tracciate %d | foglie %d invalidate %d voci cambiate %d | motivi %#x\n",
	    walltimestamp, (int)self->kv, tid, self->kep, this->wall / 1000,
	    this->cpu / 1000, (this->wall - this->cpu) / 1000, self->offn,
	    self->offmax / 1000,
	    (this->cpu - self->zap - self->wipe) / 1000, self->zap / 1000,
	    self->wipe / 1000, self->holds, self->kntr, self->klive, self->kinv,
	    self->knc, self->kfb);
	@lunghi = count();
}
fbt::vmx_vept_invept:return /self->in/ { self->in = 0; }
tick-10min
{
	printf("##### cumulativo %Y\n", walltimestamp);
	printa("  gestori INVEPT %@d, con almeno una sospensione %@d, oltre 4 ms %@d\n", @tot, @con_sosp, @lunghi);
	printa("  tempo REALE (us): %@d\n", @W);
	printa("  tempo SULLA CPU (us): %@d\n", @C);
}
