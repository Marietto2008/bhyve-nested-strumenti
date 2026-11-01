#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option aggrate=50hz
#pragma D option bufsize=16m
#pragma D option dynvarsize=32m
/* Claude 24/10/2026: COPIA per il modulo 19fc4ebf6189 (shadow VMCS v2): vmx_nested.vept_eptp12 +17792
 * (era +17760) ed exit_insn_info +0x46c8 (era +0x46a8), dal DWARF; vmx_vcpu invariato. */
/*
 * Claude 24/10/2026 -- parere #43 §6: le ~14.000 EPT violation/s dell'L1 (Hyper-V stesso, non
 * dell'L2). Sonda passiva, senza stack: vmm:vmx:exit:nestedfault (vmx.c, ramo dell'L1:
 * l'L2 e' instradato prima) con gpa (arg3) e qualificazione (arg4); vmm:vmx:exit:mmiofault per
 * le emulazioni MMIO (arg3 gpa). Per finestra da 1 s:
 *  - per regione da 2 MiB del GPA e tipo d'accesso (qual bit 0 lettura, 1 scrittura,
 *    2 esecuzione) e permessi EPT presenti (bit 3-5): conteggio;
 *  - ripetizioni: stessa pagina da 4 KiB gia' vista (insieme globale) contro pagina nuova;
 *  - le 20 pagine con piu' fault nell'ultimo secondo;
 *  - MMIO per pagina.
 */
int vista[uint64_t];
vmm:vmx:exit:nestedfault
{
	this->p = arg3 >> 12;
	this->nuova = vista[this->p] == 0;
	vista[this->p] = 1;
	@reg[(arg3 >> 21) << 21, arg4 & 7, (arg4 >> 3) & 7] = count();
	@pag[(uint64_t)(arg3 >> 12) << 12] = count();
	@nuove = sum(this->nuova); @rip = sum(!this->nuova); @tot = count();
}
vmm:vmx:exit:mmiofault
{
	@mmio[(uint64_t)(arg3 >> 12) << 12] = count();
}
tick-1s
{
	printf("S %d\n", walltimestamp);
	printa("  tot %@d nuove %@d ripetute %@d\n", @tot, @nuove, @rip);
	printa("  reg %#llx acc %d perm %d n %@d\n", @reg);
	trunc(@pag, 20);
	printa("  pag %#llx n %@d\n", @pag);
	printa("  mmio %#llx n %@d\n", @mmio);
	trunc(@reg); trunc(@pag); trunc(@mmio); trunc(@tot); trunc(@nuove); trunc(@rip);
}
