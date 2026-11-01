#pragma D option quiet
/* Claude 24/10/2026: COPIA per il modulo 19fc4ebf6189 (shadow VMCS v2): vmx_nested.vept_eptp12 +17792
 * (era +17760) ed exit_insn_info +0x46c8 (era +0x46a8), dal DWARF; vmx_vcpu invariato. */
/*
 * Claude 24/10/2026 -- parere #45 §2: tipo delle INVVPID dell'L1 (0 indirizzo singolo,
 * 1 single-context, 2 all-context, 3 single-context tranne i globali). nested_invvpid le
 * emula TUTTE con un INVVPID single-context del VPID02, cioe' svuotando l'intero TLB
 * dell'L2 di quel vCPU. Sonda passiva su vmx_nested_exit, motivo 53, per 60 s.
 * Tipo nel registro (bit 31:28 di vmx_nested.exit_insn_info, +0x46a8), letto da vmxctx
 * (vmx_vcpu +104). Offset dal DWARF del modulo 0572294.
 */
int ro[int];
BEGIN
{
	ro[0] = 0x30; ro[1] = 0x18; ro[2] = 0x10; ro[3] = 0x38; ro[5] = 0x40;
	ro[6] = 0x08; ro[7] = 0x00; ro[8] = 0x20; ro[9] = 0x28; ro[10] = 0x48;
	ro[11] = 0x50; ro[12] = 0x58; ro[13] = 0x60; ro[14] = 0x68; ro[15] = 0x70;
}
fbt::vmx_nested_exit:entry
/(*(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 136 + 20) & 0xffff) == 53/
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->r = (*(uint32_t *)(this->n + 0x46c8) >> 28) & 0xf;
	this->t = this->r == 4 ? 99 : *(uint64_t *)(arg0 + 104 + ro[this->r]);
	@tipo[this->t] = count();
	@tot = count();
}
tick-60s
{
	printf("%Y INVVPID dell'L1 in 60 s per tipo (99 = registro RSP, non letto):\n", walltimestamp);
	printa("  tipo %d: %@d\n", @tipo);
	printa("  totale %@d\n", @tot);
	exit(0);
}
