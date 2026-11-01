#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option aggrate=50hz
#pragma D option bufsize=16m
/*
 * Claude 24/10/2026 -- parere #42 §6/§9: ragioni dei VM-exit dell'L1 (Hyper-V stesso), per
 * finestre da 100 ms, sonda passiva. Ogni uscita passa da vmm:vmx:exit:entry (vmx.c,
 * vmx_exit_process) PRIMA dell'instradamento nested: in_l2 dice ancora da dove si e' usciti.
 *   arg2 = struct vm_exit * = &vcpu->exitinfo (struct vcpu di vmm.c, exitinfo +0x88);
 *   struct vcpu.cookie (+0x38) = struct vmx_vcpu *; vmx_vcpu.nested +696; vmx_nested.in_l2 +1,
 *   .vept_eptp12 +17760; vm_exit.u.vmx.exit_reason +20. Controllo: vmx_vcpu.vcpu (+8) deve
 *   puntare di nuovo alla struct vcpu ("incoerenti" deve restare 0).
 * Uscite L1 per motivo; uscite L2 per contesto (radice / WSL) e motivo.
 * Questa sonda scatta ~260.000 volte al secondo: lo script della prova la ACCENDE E SPEGNE a
 * cicli alterni, per misurarne il costo sugli stessi dati (parere #42 §9).
 * Contesti della radice: -C -D ROOTA=0x... -D ROOTB=0x... (DWARF del modulo 0572294)
 */
vmm:vmx:exit:entry
{
	this->vc = (uintptr_t)arg2 - 0x88;
	this->vv = *(uintptr_t *)(this->vc + 0x38);
	this->ok = this->vv != 0 && *(uintptr_t *)(this->vv + 8) == this->vc;
	this->n = this->ok ? *(uintptr_t *)(this->vv + 696) : 0;
	this->l2 = this->n != 0 ? *(uint8_t *)(this->n + 1) : 0;
	this->r = *(uint32_t *)(arg2 + 20) & 0xffff;
}
vmm:vmx:exit:entry /!this->ok/ { @bad = count(); }
vmm:vmx:exit:entry /this->ok && !this->l2/ { @l1[this->r] = count(); }
vmm:vmx:exit:entry /this->ok && this->l2/
{
	this->ctx = *(uint64_t *)(this->n + 17760);
	@l2[this->ctx == ROOTA || this->ctx == ROOTB ? "radice" : "wsl", this->r] = count();
}
tick-100ms
{
	printf("T %d\n", walltimestamp);
	printa("  l1 %d %@d\n", @l1);
	printa("  l2 %s %d %@d\n", @l2);
	printa("  incoerenti %@d\n", @bad);
	trunc(@l1); trunc(@l2); trunc(@bad);
}
