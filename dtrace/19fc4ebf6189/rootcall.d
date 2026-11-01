#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option aggrate=50hz
#pragma D option dynvarsize=64m
#pragma D option bufsize=16m
/* Claude 24/10/2026: COPIA per il modulo 19fc4ebf6189 (shadow VMCS v2): vmx_nested.vept_eptp12 +17792
 * (era +17760) ed exit_insn_info +0x46c8 (era +0x46a8), dal DWARF; vmx_vcpu invariato. */
/*
 * Claude 24/10/2026 -- parere #41 §4/§9 (P0), da wslres.d: sulla STESSA scala da 100 ms
 *  - hypercall della radice: VMCALL dell'L2 radice riflesse all'L1 (vmm:vmx:nested:reflect,
 *    motivo 18). Valore di input in RCX (TLFS, x64): codice = bit 0-15, fast = bit 16,
 *    nested = bit 31 (destinata all'hypervisor L0), rep_count = bit 32-43. RCX si legge dal
 *    contesto salvato del vCPU (vmx_vcpu.ctx.guest_rcx, +104+24): la riflessione non tocca
 *    i registri generali. Nessuna lettura della memoria del guest;
 *  - INVEPT dell'L1 (vmm:vmx:nested:invept), per tipo e per EPTP del descrittore: radice o
 *    altro (WSL o altre partizioni: il solo EPTP non lo prova);
 *  - come wslres.d: residenza dei VP di WSL in L2 e EPT violation riflesse.
 * Per ogni VP di WSL (GPA del VMCS12) e ogni finestra da 100 ms:
 *   ingressi (vmm:vmx:nested:enter_l2), residenza = dall'ingresso alla riflessione
 *   successiva sullo stesso thread vCPU (vmm:vmx:nested:reflect): somma, massimo e
 *   quattro classi (<10 us, 10-100 us, 0,1-1 ms, >1 ms); assenza fra una riflessione e
 *   il rientro (massimo e somma); uscite riflesse per motivo (48 EPT violation, 18 VMCALL,
 *   32 WRMSR, 1 interrupt esterno, 12 HLT, altro).
 *   ATTENZIONE: la residenza cosi' misurata e' APPROSSIMATA: comprende anche il lavoro di
 *   L0 per le uscite di WSL non riflesse (EPT02 fault ecc.). La quota hardware si ricava
 *   da partsamp.d nelle stesse finestre (guest WSL contro L0 WSL).
 * EPT violation riflesse (vmm:vmx:nested:veptrefl): tipo di accesso dai bit 0-2 della
 *   qualificazione (lettura, scrittura, esecuzione), prima volta o ripetizione per blocco
 *   da 64 KiB (insieme globale), e ogni 60 s l'istogramma cumulativo per regione da 2 MiB.
 * Contesti della radice: -C -D ROOTA=0x... -D ROOTB=0x...
 * Offset (DWARF 66a1ae3): vmx_vcpu.ctx +104 (vmxctx.guest_rcx +24, .guest_rdx +16), .vcpu +8, .nested +696, .vcpuid +704; vcpu.exitinfo +136;
 * vm_exit.u.vmx.exit_reason +20; vmx_nested.current_vmcs12 +16, .vept_eptp12 +17760.
 */
self uint64_t ent_t, ent_m;
uint64_t lastrefl[uint64_t];
int seen64[uint64_t];

vmm:vmx:nested:enter_l2
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->ctx = *(uint64_t *)(this->n + 17792);
	this->m = *(uint64_t *)(this->n + 16);
	this->wsl = this->ctx != ROOTA && this->ctx != ROOTB && this->ctx != 0;
	this->now = timestamp;
}
vmm:vmx:nested:enter_l2 /this->wsl/
{
	self->ent_t = this->now; self->ent_m = this->m;
	@ing[this->m] = count();
	this->last = lastrefl[this->m];
	this->ass = this->last && this->now > this->last ? this->now - this->last : 0;
	@ass_max[this->m] = max(this->ass / 1000);
	@ass_sum[this->m] = sum(this->ass / 1000);
}
vmm:vmx:nested:enter_l2 /!this->wsl/ { self->ent_t = 0; }

vmm:vmx:nested:reflect /self->ent_t/
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->m = *(uint64_t *)(this->n + 16);
	this->vx = *(uintptr_t *)(arg0 + 8);
	this->r = *(uint32_t *)(this->vx + 136 + 20) & 0xffff;
	this->now = timestamp;
	this->res = this->now - self->ent_t;
	@res_sum[self->ent_m] = sum(this->res / 1000);
	@res_max[self->ent_m] = max(this->res / 1000);
	@r10[self->ent_m] = sum(this->res < 10000);
	@r100[self->ent_m] = sum(this->res >= 10000 && this->res < 100000);
	@r1m[self->ent_m] = sum(this->res >= 100000 && this->res < 1000000);
	@rlong[self->ent_m] = sum(this->res >= 1000000);
	@x48[self->ent_m] = sum(this->r == 48); @x18[self->ent_m] = sum(this->r == 18);
	@x32[self->ent_m] = sum(this->r == 32); @x1[self->ent_m] = sum(this->r == 1);
	@x12[self->ent_m] = sum(this->r == 12);
	@xalt[self->ent_m] = sum(this->r != 48 && this->r != 18 && this->r != 32 && this->r != 1 && this->r != 12);
	lastrefl[self->ent_m] = this->now;
	self->ent_t = 0;
}

/* hypercall della radice */
vmm:vmx:nested:reflect
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->ctx = *(uint64_t *)(this->n + 17792);
	this->vx = *(uintptr_t *)(arg0 + 8);
	this->r = *(uint32_t *)(this->vx + 136 + 20) & 0xffff;
}
vmm:vmx:nested:reflect /(this->ctx == ROOTA || this->ctx == ROOTB) && this->r == 18/
{
	this->rcx = *(uint64_t *)(arg0 + 104 + 24);
	@hc[this->rcx & 0xffff] = count();
	@hc_rep[this->rcx & 0xffff] = sum((this->rcx >> 32) & 0xfff);
	@hc_fast[this->rcx & 0xffff] = sum((this->rcx >> 16) & 1);
	@hc_nested = sum((this->rcx >> 31) & 1);
	@hc_tot = count();
	@hc60[this->rcx & 0xffff] = count();
}
vmm:vmx:nested:reflect /(this->ctx == ROOTA || this->ctx == ROOTB) && this->r != 18/
{
	@radice_altre = count();
}

/* INVEPT dell'L1 per tipo e per EPTP del descrittore */
vmm:vmx:nested:invept
{
	@inv[arg2 == ROOTA || arg2 == ROOTB ? "radice" : "altro", arg1] = count();
	@inv60[arg2] = count();
}

vmm:vmx:nested:veptrefl /arg1 != ROOTA && arg1 != ROOTB/
{
	this->b = arg2 >> 16;
	this->nuovo = seen64[this->b] == 0;
	seen64[this->b] = 1;
	@ev_nuovo = sum(this->nuovo); @ev_rip = sum(!this->nuovo);
	@ev_r = sum((arg3 & 7) == 1); @ev_w = sum((arg3 & 2) != 0); @ev_x = sum((arg3 & 4) != 0);
	@reg[(arg2 >> 21) << 21] = count();
}

tick-100ms
{
	printf("T %d\n", walltimestamp);
	printa("  vp %#lx ing %@d res_us %@d max_us %@d r<10us %@d r<100us %@d r<1ms %@d r>1ms %@d ass_max_us %@d ass_us %@d x48 %@d x18 %@d x32 %@d x1 %@d x12 %@d xalt %@d\n",
	    @ing, @res_sum, @res_max, @r10, @r100, @r1m, @rlong, @ass_max, @ass_sum,
	    @x48, @x18, @x32, @x1, @x12, @xalt);
	printa("  ept nuovi64k %@d ripetuti %@d lettura %@d scrittura %@d esecuzione %@d\n",
	    @ev_nuovo, @ev_rip, @ev_r, @ev_w, @ev_x);
	printa("  hcall %#x n %@d rep %@d fast %@d\n", @hc, @hc_rep, @hc_fast);
	printa("  hcall_tot %@d nested %@d radice_altre_uscite %@d\n", @hc_tot, @hc_nested, @radice_altre);
	printa("  invept %s tipo %d n %@d\n", @inv);
	trunc(@hc); trunc(@hc_rep); trunc(@hc_fast); trunc(@hc_tot); trunc(@hc_nested);
	trunc(@radice_altre); trunc(@inv);
	trunc(@ing); trunc(@res_sum); trunc(@res_max); trunc(@r10); trunc(@r100); trunc(@r1m);
	trunc(@rlong); trunc(@ass_max); trunc(@ass_sum); trunc(@x48); trunc(@x18); trunc(@x32);
	trunc(@x1); trunc(@x12); trunc(@xalt);
	trunc(@ev_nuovo); trunc(@ev_rip); trunc(@ev_r); trunc(@ev_w); trunc(@ev_x);
}
tick-60s
{
	printf("##### %Y hypercall della radice per codice (ultimo minuto):\n", walltimestamp);
	printa("    hcall %#x: %@d\n", @hc60);
	printf("  INVEPT per EPTP del descrittore (ultimo minuto):\n");
	printa("    eptp %#lx: %@d\n", @inv60);
	trunc(@hc60); trunc(@inv60);
	printf("##### %Y EPT violation riflesse di WSL per regione da 2 MiB (cumulativo):\n", walltimestamp);
	printa("    regione %#lx: %@d\n", @reg);
}
