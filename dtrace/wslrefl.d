#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option aggrate=10hz
#pragma D option dynvarsize=16m
#pragma D option bufsize=8m
/*
 * Claude 24/10/2026 -- parere #38 (buchi) §4: per ogni VP di WSL (identita' = GPA del
 * VMCS12 corrente, perche' piu' VP condividono lo stesso EPTP12) un anello degli ultimi
 * 8 eventi: ingresso (vmm:vmx:nested:enter_l2) e uscita riflessa a Hyper-V
 * (vmm:vmx:nested:reflect) con motivo, qualificazione e, per le EPT violation riflesse,
 * il GPA di L2 (vmm:vmx:nested:veptrefl). Quando un VP di WSL rientra dopo oltre 200 ms
 * dalla sua ultima uscita riflessa, stampa:
 *   T_resume, il vCPU host, il tempo che i vCPU dell'L1 hanno passato in HLT nel
 *   frattempo (thread vCPU addormentati con wmesg "vmidle", cioe' dopo un'uscita HLT
 *   dell'L1 emulata da bhyve), le riflessioni della radice nel frattempo, e l'anello.
 * Contesti della radice: -D ROOTA=0x... -D ROOTB=0x... (EPTP12 visti con Windows solo).
 * Nessuna sonda per uscita: enter_l2/reflect scattano alle transizioni L1<->L2.
 * Offset (DWARF 66a1ae3): vmx_vcpu.vcpu +8, .nested +696, .vcpuid +704; vcpu.exitinfo +136;
 * vm_exit.u.vmx.exit_reason +20, .exit_qualification +24; vmx_nested.current_vmcs12 +16,
 * .vept_eptp12 +17760.
 */
uint64_t lastexit[uint64_t], hltsnap[uint64_t], rootsnap[uint64_t];
uint64_t idx[uint64_t];
uint64_t et[uint64_t, uint64_t], eq[uint64_t, uint64_t], eg[uint64_t, uint64_t];
int ek[uint64_t, uint64_t], er[uint64_t, uint64_t], ev[uint64_t, uint64_t];
int lastr[uint64_t];
uint64_t hlttot, rootrefl;
self uint64_t gpa, hs;
self int isv;

vmm:vmx:nested:veptrefl { self->gpa = arg2; }

vmm:vmx:nested:reflect
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->ctx = *(uint64_t *)(this->n + 17760);
	this->m = *(uint64_t *)(this->n + 16);
	this->vx = *(uintptr_t *)(arg0 + 8);
	this->r = *(uint32_t *)(this->vx + 136 + 20) & 0xffff;
	this->q = *(uint64_t *)(this->vx + 136 + 24);
	this->v = *(int *)(arg0 + 704);
	this->wsl = this->ctx != ROOTA && this->ctx != ROOTB && this->ctx != 0;
	self->isv = 1;
}
vmm:vmx:nested:reflect /!this->wsl/ { rootrefl++; self->gpa = 0; }
vmm:vmx:nested:reflect /this->wsl/
{
	this->k = idx[this->m] % 8;
	et[this->m, this->k] = timestamp; ek[this->m, this->k] = 2;
	er[this->m, this->k] = this->r; eq[this->m, this->k] = this->q;
	eg[this->m, this->k] = this->r == 48 ? self->gpa : 0;
	ev[this->m, this->k] = this->v;
	idx[this->m]++;
	lastexit[this->m] = timestamp; lastr[this->m] = this->r;
	hltsnap[this->m] = hlttot; rootsnap[this->m] = rootrefl;
	self->gpa = 0;
	@uscite[this->r] = count();
}

vmm:vmx:nested:enter_l2
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->ctx = *(uint64_t *)(this->n + 17760);
	this->m = *(uint64_t *)(this->n + 16);
	this->v = *(int *)(arg0 + 704);
	this->wsl = this->ctx != ROOTA && this->ctx != ROOTB && this->ctx != 0;
	this->now = timestamp;
	this->last = this->wsl ? lastexit[this->m] : 0;
	self->isv = 1;
}
vmm:vmx:nested:enter_l2
/this->last && this->now > this->last && this->now - this->last > 200000000/
{
	this->i = idx[this->m];
	printf("ASSENZA-VP %Y.%03d vmcs12 %#lx eptp12 %#lx rientra su v%d T_resume %d ms | L1 in HLT %d ms | riflessioni radice %d | ultima uscita motivo %d\n",
	    walltimestamp, (walltimestamp % 1000000000) / 1000000, this->m, this->ctx,
	    this->v, (this->now - this->last) / 1000000,
	    (hlttot - hltsnap[this->m]) / 1000000, rootrefl - rootsnap[this->m],
	    lastr[this->m]);
	@assenze[lastr[this->m], (this->now - this->last) / 1000000 > 500 ? ">500ms" : "200-500ms"] = count();
}
/* l'anello, dal piu' recente: k = (i-1) .. (i-8) mod 8, dt in us prima del rientro */
vmm:vmx:nested:enter_l2 /this->last && this->now > this->last && this->now - this->last > 200000000/
{
	this->k = (this->i + 7) % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
	this->k = (this->i + 6) % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
	this->k = (this->i + 5) % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
	this->k = (this->i + 4) % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
	this->k = (this->i + 3) % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
	this->k = (this->i + 2) % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
	this->k = (this->i + 1) % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
	this->k = this->i % 8;
	printf("    -%d us %s v%d motivo %d qual %#lx gpa %#lx\n", (this->now - et[this->m, this->k]) / 1000,
	    ek[this->m, this->k] == 1 ? "INGRESSO" : "USCITA", ev[this->m, this->k],
	    er[this->m, this->k], eq[this->m, this->k], eg[this->m, this->k]);
}
/* l'ingresso entra nell'anello DOPO la stampa */
vmm:vmx:nested:enter_l2 /this->wsl/
{
	this->k = idx[this->m] % 8;
	et[this->m, this->k] = this->now; ek[this->m, this->k] = 1;
	er[this->m, this->k] = 0; eq[this->m, this->k] = 0; eg[this->m, this->k] = 0;
	ev[this->m, this->k] = this->v;
	idx[this->m]++;
}

/* L1 in HLT: il thread vCPU dorme su "vmidle" */
sched:::off-cpu /self->isv && curthread->td_wmesg != NULL && stringof(curthread->td_wmesg) == "vmidle"/
{
	self->hs = timestamp;
}
sched:::on-cpu /self->hs/
{
	hlttot += timestamp - self->hs;
	@hlt_us = quantize((timestamp - self->hs) / 1000);
	self->hs = 0;
}

tick-60s
{
	printf("##### %Y\n  uscite riflesse di WSL per motivo:\n", walltimestamp);
	printa("    motivo %d: %@d\n", @uscite);
	printf("  assenze dei VP di WSL per ultimo motivo:\n");
	printa("    motivo %d %s: %@d\n", @assenze);
	printf("  sonni HLT dell'L1 (us):"); printa(@hlt_us);
	trunc(@uscite); trunc(@hlt_us);
}
