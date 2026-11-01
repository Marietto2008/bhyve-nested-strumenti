#pragma D option quiet
#pragma D option bufsize=64m
#pragma D option aggsize=16m
#pragma D option switchrate=2hz
/*
 * Claude 19/10/2026 -- Astra #13: cattura ATOMICA dell'ingresso in L2 che
 * inietta hw.vmm.vmx.diag_vec (0xd1 = SINT3 di STIMER0, il tick della root).
 *
 * Le tre sonde diag_* descrivono UN SOLO istante: lo stato e' fotografato nel
 * modulo immediatamente prima del VMLAUNCH/VMRESUME (non alla composizione) e
 * sparato al VM-exit successivo, dove le sonde sono lecite. Quindi:
 *   - ei/blk/rip/rfl       = cio' che l'hardware ha DAVVERO ricevuto
 *   - mt/pend/exp          = lo slot SynIC SINT3 in quello stesso istante
 *   - reason/idtvec/exitintr/rip = l'esito dell'ingresso
 *   - vmcs                 = vmptrst, il VMCS davvero caricato
 *   - vtl                  = EPTP12 corrente (SynIC/LAPIC sono privati del VTL)
 *
 * La domanda a cui risponde: quando l'hardware riceve la richiesta di iniettare
 * 0xd1, il messaggio N+1 e' GIA' visibile nello slot? E l'iniezione e' stata
 * consegnata (idtvec valido = consegnata e interrotta dall'uscita)?
 *
 * Prima: sysctl hw.vmm.vmx.diag_vec=209   (0xd1; 0 = spenta)
 *        sysctl hw.vmm.vmx.diag_slot=768  (0x300 = SINT3; difetto)
 */
int go; int64_t t0;

vmm:vmx:nested:enter_l2 /!go/
{
	go = 1; t0 = timestamp;
	printf("T0 walltimestamp=%d\n", walltimestamp);
}

/* GPA della SIM page, quando l'L2 scrive la SIMP: cambia col VTL */
vmm:vmx:nested:diag_simp
{
	printf("%10d wall=%d VP%d  SIMP agganciata  gpa=%#lx val=%#lx\n",
	    go ? (timestamp - t0) / 1000 : 0, walltimestamp, (int)arg0,
	    arg1, arg2);
}

/*
 * compose = cio' che l'L1 (Hyper-V) chiede nel VMCS12. Serve a distinguere,
 * per ogni iniezione vista all'ingresso, se viene DA VMCS12 (richiesta nuova di
 * Hyper-V) o se e' una RE-INIEZIONE di L0 di un evento abortito in consegna
 * (vm_entry_intinfo): quella non passa dal VMCS12 e la compose non la vede.
 */
vmm:vmx:nested:compose /go/
{
	this->cpu = *(int *)(arg0 + 704);
	self->c12 = (arg1 & 0x80000000) ? (arg1 & 0xffffffff) : 0;
	self->c12t = timestamp;
	@ingressi[this->cpu] = count();
	@ult_ingr[this->cpu] = max((timestamp - t0) / 1000);
}

vmm:vmx:nested:diag_entry
{
	self->ei  = arg1 & 0xffffffff;
	self->blk = arg1 >> 32;
	self->rip = arg2;
	self->mt  = arg3 & 0xffffffff;
	self->hdr = arg3 >> 32;
	self->exp = arg4;
	self->rfl = arg5;
	self->us  = go ? (timestamp - t0) / 1000 : 0;
	self->w   = walltimestamp;
}

vmm:vmx:nested:diag_exit
{
	this->idt = arg1 >> 32;
	printf("%10d wall=%d VP%d vtl=%#lx | FONTE c12=%#x eta=%dus | ING ei=%#x blk=%#x rfl=%#lx rip=%#lx | SIM mt=%#x pend=%d exp=%d | USC reason=%d idtvec=%#x exitintr=%#x rip=%#lx vmcs=%#lx\n",
	    self->us, self->w, (int)arg0, arg5,
	    (int)self->c12, self->c12t ? (timestamp - self->c12t) / 1000 : -1,
	    (int)self->ei, (int)self->blk, self->rfl, self->rip,
	    (int)self->mt, (int)((self->hdr >> 8) & 1), self->exp,
	    (int)(arg1 & 0xffff), (int)this->idt, (int)arg2, arg3, arg4);

	@inj[(int)arg0, arg5] = count();
	/* la fonte: 1 = il VMCS12 chiedeva proprio questo vettore */
	@fonte[(int)arg0, (int)(self->c12 & 0xff) == (int)(self->ei & 0xff) ? 1 : 0] = count();
	@ult[(int)arg0, arg5] = max(self->us);
	/* slot occupato all'istante dell'iniezione: il reperto chiave */
	@occ[(int)arg0, (int)self->mt] = count();
	/* esito: idtvec valido = evento consegnato e interrotto dall'uscita */
	@esito[(int)arg0, (int)(arg1 & 0xffff), (int)(this->idt >> 31)] =
	    count();
	/* l'ultimo exp iniettato: da confrontare col campionatore della pagina */
	@ultexp[(int)arg0] = max(self->exp);
}

vmm:vmx:nested:diag_more
{
	printf("%10s                      | PIU' deliv=%d act=%d eptp=%#lx rsp=%#lx\n",
	    "", arg1, (int)arg2, arg3, arg4);
}

vmm:vmx:nested:vmfail /go/
{
	printf("%10d VP%d VM-ENTRY FALLITA err=%d\n", (timestamp - t0) / 1000,
	    *(int *)(arg0 + 704), (int)arg1);
}

tick-10s /go/
{
	printf("=== %d s  wall=%d\n", (timestamp - t0) / 1000000000,
	    walltimestamp);
	printa("  ingressi in L2 (VP%d) = %@d\n", @ingressi);
	printa("  ultimo ingresso (VP%d) = %@d us\n", @ult_ingr);
	printa("  iniezioni (VP%d, VTL %#lx) = %@d\n", @inj);
	printa("  fonte (VP%d) dal_vmcs12=%d = %@d\n", @fonte);
	printa("  ultima    (VP%d, VTL %#lx) = %@d us\n", @ult);
	printa("  slot all'iniezione (VP%d) mt=%#x = %@d\n", @occ);
	printa("  esito     (VP%d) reason %d idtvec_valid %d = %@d\n", @esito);
	printa("  ultimo exp iniettato (VP%d) = %@d\n", @ultexp);
}
