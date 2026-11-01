/*
 * sonde-wsl-v2.d -- Claude 01/11/2026. Il programma DTrace di una corsa della campagna Hyper-V/WSL2 (run-wsl-corsa.sh),
 * dopo la corsa 2 del 01/11 (CreateVm/ERROR_TIMEOUT con l'L2 che girava il triplo): come sonde-wsl-v1.d, piu' la
 * distribuzione dei MOTIVI d'uscita dell'L2, per finestra di 10 s, per separare "L2 lento" da "L2 in un giro":
 *   - nested_l2_exit:entry       ogni uscita dell'L2: MISURATO fino a 3*10^5/s (campagna 2, 92-94% EPT VIOLATION),
 *                                non 10^4/s come stimato: la sonda NON e' leggera, il suo costo non e' misurato;
 *   - nested_reflect_to_l1:entry quelle consegnate all'L1 (Hyper-V), fino a circa 1,4*10^4/s.
 * Il modulo non ha CTF: il motivo si legge per offset da struct vm_exit (arg1): exitcode 0, inst_length 4, rip 8,
 * u.vmx.status 16, u.vmx.exit_reason 20 (sys/amd64/include/vmm.h dello stadio 10), bit 15:0. L'offset e l'argomento
 * (arg1 = struct vm_exit * in nested_l2_exit e nested_reflect_to_l1) valgono SOLO per il build dello stadio 10
 * (vmm-restore.ko 142a08b6..., che run-wsl-corsa.sh esige al preflight): per un altro build vanno riverificati sul
 * suo vmm.h e sulle firme delle due funzioni (parere #171 di Astra, par. 5).
 * Per finestra: una riga "F <epoca>" (secondi, walltimestamp), poi "L2 <motivo> <n>" e "RIF <motivo> <n>".
 * Stesso contratto della v1: prima riga "DTRACE_ATTIVO sonde-wsl-v2", $1 = limite in secondi (DTRACE_SCADUTO), solo
 * stdout. Niente FBT sui gestori caldi dell'L1 (nested_vmread/vmwrite: milioni di chiamate).
 */
#pragma D option quiet
#pragma D option aggsize=4m

BEGIN { inizio = timestamp; printf("DTRACE_ATTIVO sonde-wsl-v2\n"); }
fbt:vmm-restore:vmx_shvmcs_enter:entry { @n["vmx_shvmcs_enter"] = count(); }
fbt:vmm-restore:nested_l2_exit:entry { @l2[*(uint32_t *)(arg1 + 20) & 0xffff] = count(); }
fbt:vmm-restore:nested_reflect_to_l1:entry { @rif[*(uint32_t *)(arg1 + 20) & 0xffff] = count(); }
vmm:vmx:nested:opndfatal { printf("OPNDFATAL vcpu=%d stadio=%d err=%d rip=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4); }
vmm:vmx:nested:veptunemul { printf("VEPTUNEMUL vcpu=%d\n", arg0); }
vmm:::fatal-latch { printf("FATAL_LATCH vcpu=%d errno=%d stadio=%d rip=%#lx gpa=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4, arg5); }
vmm:::fatal-ritorno { printf("FATAL_RITORNO vcpu=%d nextrip=%#lx rip=%#lx len=%d fatal_rip=%#lx\n", arg0, arg1, arg2, arg3, arg4); }
tick-10s
{
	printf("F %d\n", walltimestamp / 1000000000);
	printa("L2 %d %@d\n", @l2);
	printa("RIF %d %@d\n", @rif);
	trunc(@l2); trunc(@rif);
}
END
{
	printf("F %d\n", walltimestamp / 1000000000);
	printa("L2 %d %@d\n", @l2);
	printa("RIF %d %@d\n", @rif);
	printa("FBT %s %@d\n", @n);
	printf("DTRACE_FINE\n");
}
tick-1s /timestamp - inizio > $1 * 1000000000ULL/ { printf("DTRACE_SCADUTO\n"); exit(0); }
