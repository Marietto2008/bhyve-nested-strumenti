#pragma D option quiet
#pragma D option switchrate=4hz
#pragma D option dynvarsize=16m
/*
 * Claude 20/10/2026 -- la GENESI del #UD che uccide smss. Con diag_vec=6:
 * alla cattura del #UD all'ingresso (diag) dump degli ULTIMI eventi di quel VP.
 * Si registra, per ogni VP, una finestra scorrevole delle ultime uscite L2
 * (reason, rip) e ogni vm_exit_intinfo (L0 salva un evento interrotto) e
 * vm_inject_exception (L0 decide un'eccezione). Quando scatta il #UD, si
 * stampa cosa c'era subito prima.
 */
int go; int64_t t0;
int r1[int]; uint64_t rip1[int]; int r2[int]; uint64_t rip2[int]; int r3[int]; uint64_t rip3[int];

vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

fbt:vmm-restore:nested_l2_exit:entry /go/
{
	this->cpu = *(int *)(arg0 + 704);
	r3[this->cpu]=r2[this->cpu]; rip3[this->cpu]=rip2[this->cpu];
	r2[this->cpu]=r1[this->cpu]; rip2[this->cpu]=rip1[this->cpu];
	r1[this->cpu]=*(uint32_t *)(arg1 + 20) & 0xffff; rip1[this->cpu]=*(uint64_t *)(arg1 + 8);
}

/* L0 salva un evento interrotto durante la consegna */
fbt:vmm-restore:vm_exit_intinfo:entry /go/
{
	printf("%10d SAVE intinfo=%#lx (vett=%d tipo=%d)\n", (timestamp - t0) / 1000,
	    arg1, (int)(arg1 & 0xff), (int)((arg1 >> 8) & 7));
}
fbt:vmm-restore:vm_inject_exception:entry /go/
{
	printf("%10d L0 inject exc vett=%d\n", (timestamp - t0) / 1000, (int)arg1);
}

vmm:vmx:nested:diag_entry { self->ei = arg1 & 0xffffffff; self->rip = arg2; self->us = (timestamp - t0) / 1000; }
vmm:vmx:nested:diag_exit /self->ei != 0 && !self->done/
{
	this->cpu = (int)arg0;
	printf("%10d #UD VP%d rip=%#lx. Ultime 3 uscite di questo VP: [r=%d rip=%#lx] [r=%d rip=%#lx] [r=%d rip=%#lx]\n",
	    self->us, this->cpu, self->rip,
	    r1[this->cpu], rip1[this->cpu], r2[this->cpu], rip2[this->cpu], r3[this->cpu], rip3[this->cpu]);
	self->done = 1;	/* solo il primo per thread, per non annegare */
}
