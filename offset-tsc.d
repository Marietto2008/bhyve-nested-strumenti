#!/usr/sbin/dtrace -qs
/*
 * offset-tsc.d -- Claude 15/11/2026, prova (b): chi scrive l'offset TSC dei vCPU (vmx_set_tsc_offset) e con che valore.
 * Da lanciare PRIMA di avviare la VM (sudo dtrace -qs offset-tsc.d -o file). Per ogni scrittura: ora (ns dal lancio),
 * vCPU, offset, rdtsc dell'host, e lo stack (MSR TSC dall'ospite = vmx_wrmsr; da QEMU = ioctl VM_SET_REGISTER/restore).
 * Lo sfasamento tra due vCPU e' la differenza dei loro offset (stesso TSC dell'host). Solo fbt: niente -p.
 */
BEGIN { t0 = timestamp; }
fbt::vmx_set_tsc_offset:entry
{
	/* niente CTF per struct vmx_vcpu: il vCPU si riconosce dal puntatore (uno per vCPU, nell'ordine di creazione) */
	printf("%d.%09d vcpu=%p offset=%d (0x%x) cpu=%d\n", (timestamp - t0) / 1000000000, (timestamp - t0) % 1000000000,
	    arg0, (int64_t)arg1, arg1, cpu);
	stack(6);
}
