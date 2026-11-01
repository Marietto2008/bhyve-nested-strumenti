/*
 * banco-r1.c -- Claude 01/11/2026, P3 stadio 11 (parere #158 R1). Usa il vm_run VERO del clone dello stadio 11
 * (funzioni.inc estratto da run.sh): un'uscita nested segnalata CONTESO diventa BOGUS e prende il percorso servito,
 * senza azzerare il conteggio dei cicli nested veri.
 *   R1a: ciclo nested VERO (l'uscita resta NESTED)            -> panic diagnostico a 2.000.000, come prima
 *   R1b: NESTED -> INST_EMUL (MMIO dell'L1)                     -> BOGUS a userland dopo 4096, come prima
 *   R1c: contesa PERSISTENTE (ogni uscita NESTED e' CONTESO)    -> nessun panic, BOGUS a userland dopo 4096,
 *        inst_length 0, l'istruzione non avanza mai, flag spento
 *   R1d: ciclo VERO con una contesa ogni 1000 uscite            -> panic quando i cicli VERI arrivano a 2.000.000
 *        (la contesa non li azzera)
 *   R1e: flag acceso su un'uscita INST_EMUL, poi ciclo VERO     -> il flag si spegne li', nessuna conversione: panic
 *   R1f: flag acceso su un'uscita che va a userland (RDMSR)     -> torna RDMSR, non BOGUS, flag spento
 * Uso: banco-r1 <albero>
 */
#include "stub.h"

static u_long vm_fatal_latches;

#include "funzioni.inc"

static int nf, nok;
static struct vm vm;
static struct vcpu v;
#define VERO(c, ...) do { if (c) { nok++; } else { nf++; printf("  ERRATO  "); printf(__VA_ARGS__); printf("  [%s]\n", #c); } } while (0)

static void nuovo(void)
{
	memset(&sc, 0, sizeof(sc));
	memset(&vm, 0, sizeof(vm));
	memset(&v, 0, sizeof(v));
	vm.active_cpus = 1;
	v.vm = &vm;
	vcpu_init(&v);
	v.nextrip = 0x1000;
	sc.decode_len = 3;
	sc.gpa = DEFAULT_APIC_BASE;
	for (int i = 0; i < 64; i++)
		sc.prossima[i] = VM_EXITCODE_NESTED;	/* ogni ingresso esce NESTED (dal 63 in poi resta l'ultima) */
	sc.cattura_panic = 1;
}

/* esegue vm_run; 1 se e' finito in panic */
static int corri(int *e)
{
	*e = -1;
	if (setjmp(sc.salto_panic) != 0)
		return (1);
	*e = vm_run(&v);
	return (0);
}

static bool rip_fermo(void)
{
	for (int i = 0; i < 64; i++)
		if (sc.rip_entrata[i] != 0x1000)
			return (false);
	return (true);
}

int main(int argc, char **argv)
{
	const char *albero = argc > 1 ? argv[1] : "?";
	int e, p;
	long atteso;

	printf("banco R1 stadio 11 (%s)\n", albero);

	nuovo(); sc.nested_resta = 1;
	p = corri(&e);
	VERO(p && sc.panici == 1 && sc.entrate == 2000000, "R1a ciclo vero: panic %d ingressi %d", p, sc.entrate);

	nuovo(); sc.nested_resta = 0;
	p = corri(&e);
	VERO(!p && e == 0 && sc.entrate == 4096 && v.exitinfo.exitcode == VM_EXITCODE_BOGUS,
	    "R1b NESTED->INST_EMUL: panic %d vm_run %d ingressi %d exitcode %d", p, e, sc.entrate, v.exitinfo.exitcode);

	nuovo(); sc.nested_resta = 1; sc.conteso_ogni = 1;
	p = corri(&e);
	VERO(!p && e == 0 && sc.panici == 0 && sc.entrate == 4096 && v.exitinfo.exitcode == VM_EXITCODE_BOGUS &&
	    v.exitinfo.inst_length == 0 && rip_fermo() && v.nextrip == 0x1000 && !v.gla2gpa_conteso &&
	    sc.conteso_segnalati == 4096 && sc.yield > 0 && kassert_fallite == 0,
	    "R1c contesa persistente: panic %d vm_run %d ingressi %d exitcode %d ilen %d rip fermo %d nextrip %#lx flag %d segnalati %ld yield %ld",
	    p, e, sc.entrate, v.exitinfo.exitcode, v.exitinfo.inst_length, rip_fermo(), (u_long)v.nextrip,
	    v.gla2gpa_conteso, sc.conteso_segnalati, sc.yield);
	printf("  info    R1c: contesa persistente -> nessun panic, BOGUS a userland dopo %d ingressi (kern_yield %ld), istruzione mai avanzata\n",
	    sc.entrate, sc.yield);

	nuovo(); sc.nested_resta = 1; sc.conteso_ogni = 1000;
	for (atteso = 2000000; atteso - atteso / 1000 != 2000000 || atteso % 1000 == 0; atteso++)
		;
	p = corri(&e);
	VERO(p && sc.panici == 1 && sc.entrate == atteso && sc.conteso_segnalati == atteso / 1000,
	    "R1d ciclo vero con contesa ogni 1000: panic %d ingressi %d (attesi %ld) segnalati %ld", p, sc.entrate, atteso,
	    sc.conteso_segnalati);
	printf("  info    R1d: %ld contese intercalate non azzerano il conteggio: panic dopo %d ingressi (2.000.000 veri)\n",
	    sc.conteso_segnalati, sc.entrate);

	nuovo(); sc.nested_resta = 1; sc.prossima[0] = VM_EXITCODE_INST_EMUL; sc.flag_vagante_a = 1;
	p = corri(&e);
	VERO(p && sc.panici == 1 && sc.entrate == 2000001 && !v.gla2gpa_conteso,
	    "R1e flag su INST_EMUL poi ciclo vero: panic %d ingressi %d flag %d", p, sc.entrate, v.gla2gpa_conteso);

	nuovo(); sc.prossima[0] = VM_EXITCODE_RDMSR; sc.flag_vagante_a = 1;
	p = corri(&e);
	VERO(!p && e == 0 && sc.entrate == 1 && v.exitinfo.exitcode == VM_EXITCODE_RDMSR && !v.gla2gpa_conteso,
	    "R1f flag su RDMSR: panic %d vm_run %d ingressi %d exitcode %d flag %d", p, e, sc.entrate, v.exitinfo.exitcode,
	    v.gla2gpa_conteso);

	printf("%s: %d ok, %d errati\n", albero, nok, nf);
	return (nf != 0);
}
