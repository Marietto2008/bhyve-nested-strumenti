/*
 * sonde-wsl-v1.d -- Claude 01/11/2026. Il programma DTrace di una corsa della campagna Hyper-V/WSL2 sullo stadio 10
 * (run-wsl-corsa.sh). Stesso schema di sonde-opnd-v2.d:
 *   - prima riga "DTRACE_ATTIVO sonde-wsl-v1" (il verdetto la esige);
 *   - $1 = limite in secondi (intero), oltre il quale la traccia si chiude da sola (DTRACE_SCADUTO);
 *   - scrive solo su stdout (il file lo crea il chiamante).
 * Niente FBT sui gestori caldi (nested_vmread/vmwrite: milioni di chiamate con Windows): solo vmx_shvmcs_enter, che
 * serve al contratto dell'ombra, e le sonde del latch, che in una corsa sana non scattano mai.
 */
#pragma D option quiet

BEGIN { inizio = timestamp; printf("DTRACE_ATTIVO sonde-wsl-v1\n"); }
fbt:vmm-restore:vmx_shvmcs_enter:entry { @n["vmx_shvmcs_enter"] = count(); }
vmm:vmx:nested:opndfatal { printf("OPNDFATAL vcpu=%d stadio=%d err=%d rip=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4); }
vmm:vmx:nested:veptunemul { printf("VEPTUNEMUL vcpu=%d\n", arg0); }
vmm:::fatal-latch { printf("FATAL_LATCH vcpu=%d errno=%d stadio=%d rip=%#lx gpa=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4, arg5); }
vmm:::fatal-ritorno { printf("FATAL_RITORNO vcpu=%d nextrip=%#lx rip=%#lx len=%d fatal_rip=%#lx\n", arg0, arg1, arg2, arg3, arg4); }
END { printa("FBT %s %@d\n", @n); printf("DTRACE_FINE\n"); }
tick-1s /timestamp - inizio > $1 * 1000000000ULL/ { printf("DTRACE_SCADUTO\n"); exit(0); }
