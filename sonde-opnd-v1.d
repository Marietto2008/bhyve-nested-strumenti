/*
 * sonde-opnd-v1.d -- Claude 01/11/2026, parere Opus «letture chiuse» par. 4.3. Il programma DTrace delle sessioni KUT
 * dell'operando (run-opnd-kut.sh v13+), estratto dal runner: e' un artefatto con il suo sha nell'elenco approvato.
 *   - si identifica nella traccia: la prima riga e' "DTRACE_ATTIVO sonde-opnd-v1" (il verdetto v9 la esige);
 *   - $1 = limite in secondi (intero) oltre il quale la traccia si chiude da sola (DTRACE_SCADUTO): un argomento
 *     macro, non testo sostituito;
 *   - scrive SOLO su stdout: il file lo crea il chiamante (root non scrive nei percorsi di marietto, par. 4.1).
 * Uso: dtrace -s sonde-opnd-v1.d <limite in secondi>
 */
#pragma D option quiet

BEGIN { inizio = timestamp; printf("DTRACE_ATTIVO sonde-opnd-v1\n"); }
fbt:vmm-restore:nested_vmread:entry { @n["nested_vmread"] = count(); }
fbt:vmm-restore:nested_vmwrite:entry { @n["nested_vmwrite"] = count(); }
fbt:vmm-restore:nested_operand_copy:entry { @n["nested_operand_copy"] = count(); }
fbt:vmm-restore:vmx_shvmcs_enter:entry { @n["vmx_shvmcs_enter"] = count(); }
END { printa("FBT %s %@d\n", @n); printf("DTRACE_FINE\n"); }
vmm:vmx:nested:opndfatal { printf("OPNDFATAL vcpu=%d stadio=%d err=%d rip=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4); }
vmm:::fatal-latch { printf("FATAL_LATCH vcpu=%d errno=%d stadio=%d rip=%#lx gpa=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4, arg5); }
vmm:::fatal-ritorno { printf("FATAL_RITORNO vcpu=%d nextrip=%#lx rip=%#lx len=%d fatal_rip=%#lx\n", arg0, arg1, arg2, arg3, arg4); }
tick-1s /timestamp - inizio > $1 * 1000000000/ { printf("DTRACE_SCADUTO\n"); exit(0); }
