/*
 * msix-vept.d -- Claude 10/11/2026, diagnosi Fable 020 §3.2 (rete di Windows con MSI-X mai programmata).
 * SOLO il percorso lento delle EPT violation dell'L2 (vmx_vept_fault, ~decine di milioni per avvio; il percorso
 * d'ingresso in L2, ~100 milioni, NON si tocca: le sonde su compose sopprimevano il panic LAPIC).
 * Filtro sull'L2-GPA delle due pagine delle tabelle MSI-X (per la radice di Hyper-V l'EPT12 e' identita':
 * si stampa anche l'L1-GPA per verificarlo):
 *   virtio-net BAR1 0x81046000 (tabella +0, PBA +0x800);  xHCI BAR0+0x3000 = 0x1000007000.
 * Esito: 0 VEPT_OK = foglia EPT02 INSTALLATA su quella pagina (prova di M1: le scritture successive non escono);
 *        3 VEPT_MMIO = uscita verso l'emulazione (QEMU deve vederla in msix_table_write); 1/2 riflessa all'L1.
 * Piu' i cambi di generazione della mappa di memoria (veptmemgen), rari.
 * Uso: dtrace -qs msix-vept.d  (da avviare PRIMA della VM, si ferma con SIGINT)
 */
#pragma D option quiet
#pragma D option switchrate=10hz

BEGIN
{
	printf("%Y msix-vept.d attiva\n", walltimestamp);
}

fbt:vmm-restore:vmx_vept_fault:entry
/(arg1 >= 0x81046000 && arg1 < 0x81047000) || (arg1 >= 0x1000007000 && arg1 < 0x1000008000)/
{
	self->t = 1;
	self->gpa = arg1;
	self->qual = arg2;
	self->pl1 = (uint64_t *)arg3;
}

fbt:vmm-restore:vmx_vept_fault:return
/self->t/
{
	printf("%Y %d vept_fault gpa=0x%x qual=0x%x esito=%d %s l1gpa=0x%x\n", walltimestamp, timestamp,
	    self->gpa, self->qual, arg1,
	    arg1 == 0 ? "OK-FOGLIA-INSTALLATA" : arg1 == 3 ? "MMIO" : arg1 == 1 ? "VIOL" : "MISCONF",
	    *self->pl1);
	self->t = 0;
}

vmm:vmx:nested:veptmemgen
{
	printf("%Y %d memgen vcpu=%d gen=0x%x radici_svuotate=%d\n", walltimestamp, timestamp, arg0, arg1, arg2);
}
