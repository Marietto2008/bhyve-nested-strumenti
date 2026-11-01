/*
 * sonde-wsl-v3.d -- Claude 01/11/2026, parere #172 di Astra (D2). Il programma DTrace di una corsa WSL (run-wsl-corsa.sh)
 * per la qualifica limitata: corsa di riferimento sullo stadio 10, poi stadio 11. Rispetto alla v2 TOGLIE la fbt su
 * ogni uscita dell'L2 (nested_l2_exit, misurata fino a 3*10^5/s) e misura, per finestra di 10 s:
 *   C   compose totali: ogni ingresso emulato L1 -> L2 (nested_compose_vmcs02, vmx_nested.c:5241 s10 / stessa riga
 *       logica s11; l'unico ritorno anticipato della funzione e' un errore). arg1 = ENTRY_INTR_INFO del VMCS12, cioe'
 *       l'evento che l'L1 PREDISPONE per l'ingresso: non certifica la consegna. Circa 10^4/s.
 *   CV  compose con arg1 VALIDO (bit 31): tipo (bit 10:8) e vettore (bit 7:0) decodificati SOLO se valido.
 *   CS  stato dell'L2 al compose: RFLAGS.IF (arg4 bit 41) e interrompibilita' STI/MOV-SS (arg4 bit 1:0).
 *   D   defer (nested_check_events): vcpuid, tipo del rinvio 1/2, tipo e vettore dell'evento L2 (arg2), vettore L1
 *       (arg3). Sono OSSERVAZIONI di rinvio, non eventi originari unici: lo stesso pendente puo' ricomparire.
 *   IA  immexit op 1 (armate) per vcpuid e tipo (arg2).
 *   IF  immexit op 2 (arrivate) per vcpuid: nel sorgente kind = 0, quindi NON attribuite a un tipo.
 *   IO  immexit op 3 (timer dell'L1 in uso) e 4 (CPU senza timer) per vcpuid.
 *   RIF riflessioni all'L1 per motivo: fbt nested_reflect_to_l1, motivo all'OFFSET 20 di struct vm_exit (arg1).
 *       Layout verificato identico nei build dello stadio 10 (142a08b6...) e 11 (3bfc6ae8...): sys/amd64/include/vmm.h
 *       dei due cloni, struct vm_exit senza differenze; firma (struct vmx_vcpu *, struct vm_exit *) in entrambi. Per
 *       ALTRI build va riverificato.
 * Chiave d'identita' comune alle quattro famiglie: tid, il thread del vCPU (bhyve ne ha uno per vCPU). La
 * corrispondenza tid -> vcpuid (da D/IA/IF/IO) e tid -> puntatore vmx_vcpu (da C/RIF) e' stampata alla fine
 * (MAPV, MAPP): il lettore verifica che sia 1:1. tid NON e' la CPU fisica. Il contesto L2 (il Linux di WSL o un altro
 * contesto di Hyper-V) NON e' identificato da queste sonde.
 * Contratto come v1/v2: prima riga "DTRACE_ATTIVO sonde-wsl-v3", $1 = limite in secondi (DTRACE_SCADUTO), solo
 * stdout; per finestra una riga "F <epoca>" seguita dagli aggregati della finestra che FINISCE a quell'epoca.
 */
#pragma D option quiet
#pragma D option aggsize=8m

BEGIN { inizio = timestamp; printf("DTRACE_ATTIVO sonde-wsl-v3\n"); }
fbt:vmm-restore:vmx_shvmcs_enter:entry { @n["vmx_shvmcs_enter"] = count(); }

vmm:vmx:nested:compose { @c[tid] = count(); @mapp[tid, arg0] = count(); }
vmm:vmx:nested:compose /arg1 & 0x80000000/ { @cv[tid, (arg1 >> 8) & 7, arg1 & 0xff] = count(); }
vmm:vmx:nested:compose { @cs[tid, (arg4 >> 41) & 1, arg4 & 3] = count(); }

vmm:vmx:nested:defer { @d[tid, arg0, arg1, (arg2 >> 8) & 7, arg2 & 0xff, arg3] = count(); @mapv[tid, arg0] = count(); }
vmm:vmx:nested:immexit /arg1 == 1/ { @ia[tid, arg0, arg2] = count(); @mapv[tid, arg0] = count(); }
vmm:vmx:nested:immexit /arg1 == 2/ { @arr[tid, arg0] = count(); @mapv[tid, arg0] = count(); }
vmm:vmx:nested:immexit /arg1 == 3 || arg1 == 4/ { @io[tid, arg0, arg1] = count(); }

fbt:vmm-restore:nested_reflect_to_l1:entry { @rif[tid, *(uint32_t *)(arg1 + 20) & 0xffff] = count(); @mapp[tid, arg0] = count(); }

vmm:vmx:nested:opndfatal { printf("OPNDFATAL vcpu=%d stadio=%d err=%d rip=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4); }
vmm:vmx:nested:veptunemul { printf("VEPTUNEMUL vcpu=%d\n", arg0); }
vmm:::fatal-latch { printf("FATAL_LATCH vcpu=%d errno=%d stadio=%d rip=%#lx gpa=%#lx gla=%#lx\n", arg0, arg1, arg2, arg3, arg4, arg5); }
vmm:::fatal-ritorno { printf("FATAL_RITORNO vcpu=%d nextrip=%#lx rip=%#lx len=%d fatal_rip=%#lx\n", arg0, arg1, arg2, arg3, arg4); }

tick-10s
{
	printf("F %d\n", walltimestamp / 1000000000);
	printa("C %d %@d\n", @c);
	printa("CV %d %d %d %@d\n", @cv);
	printa("CS %d %d %d %@d\n", @cs);
	printa("D %d %d %d %d %d %d %@d\n", @d);
	printa("IA %d %d %d %@d\n", @ia);
	printa("IF %d %d %@d\n", @arr);
	printa("IO %d %d %d %@d\n", @io);
	printa("RIF %d %d %@d\n", @rif);
	trunc(@c); trunc(@cv); trunc(@cs); trunc(@d); trunc(@ia); trunc(@arr); trunc(@io); trunc(@rif);
}
END
{
	printf("F %d\n", walltimestamp / 1000000000);
	printa("C %d %@d\n", @c);
	printa("CV %d %d %d %@d\n", @cv);
	printa("CS %d %d %d %@d\n", @cs);
	printa("D %d %d %d %d %d %d %@d\n", @d);
	printa("IA %d %d %d %@d\n", @ia);
	printa("IF %d %d %@d\n", @arr);
	printa("IO %d %d %d %@d\n", @io);
	printa("RIF %d %d %@d\n", @rif);
	printa("MAPV %d %d %@d\n", @mapv);
	printa("MAPP %d %p %@d\n", @mapp);
	printa("FBT %s %@d\n", @n);
	printf("DTRACE_FINE\n");
}
tick-1s /timestamp - inizio > $1 * 1000000000ULL/ { printf("DTRACE_SCADUTO\n"); exit(0); }
