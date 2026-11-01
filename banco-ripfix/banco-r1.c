/*
 * banco-r1.c -- Claude 30/10/2026, parere #157 §4 (R1). Usa il vm_run VERO del clone nested (funzioni.inc estratto
 * da run.sh) per misurare quale percorso del giro di vm_run accumula nested_loops fino al panic diagnostico:
 *   R1a: uscita NESTED che RESTA NESTED (istruzione VMX gestita; il ramo di una contesa nell'operando VMX)
 *   R1b: uscita NESTED convertita in INST_EMUL dallo slow path (MMIO dell'L1 emulato; i rami fetch/MOVS/stack)
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

int main(int argc, char **argv)
{
	const char *albero = argc > 1 ? argv[1] : "?";
	int e;

	printf("banco R1 (%s)\n", albero);

	/* R1a: l'uscita resta NESTED a ogni giro (una contesa persistente nell'operando VMX, ripartita) */
	nuovo(); sc.nested_resta = 1;
	if (setjmp(sc.salto_panic) == 0) {
		e = vm_run(&v);
		printf("  info    R1a: vm_run e' tornato da solo (%d) dopo %d ingressi\n", e, sc.entrate);
	}
	VERO(sc.panici == 1 && sc.entrate == 2000000, "R1a panici %d ingressi %d", sc.panici, sc.entrate);
	printf("  info    R1a: uscita che RESTA NESTED -> PANIC dopo %d ingressi (kern_yield %ld), senza mai tornare a userland\n",
	    sc.entrate, sc.yield);

	/* R1b: lo slow path converte in INST_EMUL e l'emulazione riesce: nested_loops si azzera, e il giro torna a
	 * userland ogni 4096 uscite (BOGUS) */
	nuovo(); sc.nested_resta = 0;
	if (setjmp(sc.salto_panic) == 0) {
		e = vm_run(&v);
		VERO(e == 0 && sc.panici == 0 && sc.entrate == 4096 && v.exitinfo.exitcode == VM_EXITCODE_BOGUS,
		    "R1b vm_run %d panici %d ingressi %d exitcode %d", e, sc.panici, sc.entrate, v.exitinfo.exitcode);
		printf("  info    R1b: NESTED -> INST_EMUL: nessun panic, ritorno a userland (BOGUS) dopo %d ingressi\n", sc.entrate);
	} else
		VERO(0, "R1b: PANIC inatteso dopo %d ingressi", sc.entrate);

	printf("%s: %d ok, %d errati\n", albero, nok, nf);
	return (nf != 0);
}
