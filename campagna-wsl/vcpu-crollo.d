#!/usr/sbin/dtrace -qs
/*
 * Fotografia dei vCPU attorno al crollo del disco (nesting + passthrough).
 * Ogni 500 ms: per vCPU, motivi d'uscita (vm_exit +20), ingressi in L2 e
 * uscite riflesse all'L1 (vmx_vcpu +704 = vcpuid); attivita' del disco
 * (VEPT_MMIO sulla pagina AHCI c200a000) e interrupt dei dispositivi passati.
 * Solo kernel, nessun -p.
 */
#pragma D option dynvarsize=16m
#pragma D option bufsize=32m
vmm:vmx:exit:entry { @ex[arg1, *(uint32_t *)((uintptr_t)arg2 + 20)] = count(); }
vmm:vmx:nested:enter_l2 { @l2[*(int *)((uintptr_t)arg0 + 704)] = count(); }
vmm:vmx:nested:reflect { @rf[*(int *)((uintptr_t)arg0 + 704)] = count(); }
fbt:vmm-restore:vmx_vept_fault:entry { self->p = arg3; }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3 && (*(uint64_t *)self->p >> 12) == 0xc200a/ { @disco = count(); }
fbt:vmm-restore:vmx_vept_fault:return { self->p = 0; }
fbt:vmm-restore:pptintr:entry { @ppt = count(); }
tick-500ms
{
	printf("--- %Y.%03d\n", walltimestamp, (walltimestamp % 1000000000) / 1000000);
	printa("  disco(AHCI) %@d\n", @disco); printa("  pptintr %@d\n", @ppt);
	printa("  v%d L2in %@d\n", @l2); printa("  v%d refl %@d\n", @rf);
	trunc(@ex, 24); printa("  v%d motivo %d: %@d\n", @ex);
	trunc(@disco); trunc(@ppt); trunc(@l2); trunc(@rf); trunc(@ex);
}
