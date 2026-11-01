/*
 * banco.c -- Claude 01/11/2026, P3 stadio 11 (parere #158 D1). Esercita la funzione VERA _vm_gla2gpa dello stadio 11
 * (funzioni.inc, estratta da run.sh) contro l'avversario di stub.h (lo stesso del banco P3 del 30/10).
 *   L: i chiamanti LEGACY (conteso == NULL: vm_gla2gpa, vm_gla2gpa_nofault) si comportano ESATTAMENTE come prima,
 *      compresa la contesa persistente che non torna (P3 resta per loro: Astra, nessuna abilitazione globale);
 *   B: i chiamanti MIGRATI (conteso != NULL: l'operando VMX nested) ricevono CONTESO dopo esattamente
 *      gla2gpa_restart_max ripartenze: ritorno 0, fault 0, nessuna pagina tenuta, nessuna eccezione, nessuna
 *      ripartenza dell'istruzione (la fa il gestore), contatore gla2gpa_restart_capped +1.
 * Uso: banco <nome-albero>
 */
#include "stub.h"
static u_int gla2gpa_restart_max = 64;		/* come nel sorgente; i casi lo cambiano */
static u_long gla2gpa_restart_capped;
#include "funzioni.inc"

static int nf, nok;
#define VERO(c, ...) do { if (c) { nok++; } else { nf++; printf("  ERRATO  "); printf(__VA_ARGS__); printf("  [%s]\n", #c); } } while (0)
#define INFO(...) do { printf("  info    "); printf(__VA_ARGS__); printf("\n"); } while (0)

#define GLA	0x400123UL
#define GPA_ATTESO	(5UL * PAGE_SIZE + 0x123)
static volatile uint64_t *voce[4];
static struct vm_guest_paging pg;
static struct vcpu vc;

static void tabelle(void)
{
	memset(mem, 0, sizeof(mem));
	uint64_t *pml4 = (uint64_t *)(mem + 1 * PAGE_SIZE), *pdpt = (uint64_t *)(mem + 2 * PAGE_SIZE);
	uint64_t *pd = (uint64_t *)(mem + 3 * PAGE_SIZE), *pt = (uint64_t *)(mem + 4 * PAGE_SIZE);
	pml4[0] = 2 * PAGE_SIZE | PG_V | PG_RW | PG_U;
	pdpt[0] = 3 * PAGE_SIZE | PG_V | PG_RW | PG_U;
	pd[2] = 4 * PAGE_SIZE | PG_V | PG_RW | PG_U;
	pt[0] = 5 * PAGE_SIZE | PG_V | PG_RW | PG_U;
	voce[0] = &pml4[0]; voce[1] = &pdpt[0]; voce[2] = &pd[2]; voce[3] = &pt[0];
	pg.cr3 = 1 * PAGE_SIZE; pg.cpl = 0; pg.cpu_mode = CPU_MODE_64BIT; pg.paging_mode = PAGING_MODE_64;
	ripartenze = cas_tentati = cas_sabotati = ept_eagain = 0;
	iniezioni_pf = iniezioni_gp = ripartenze_istruzione = eventi_nested = 0;
	avv_cas = avv_ept = 0;
	nega_finale = 0;
	holds_attivi = 0;
	gla2gpa_restart_capped = 0;
	gla2gpa_restart_max = 64;
}

/* un walk: conteso NULL = chiamante legacy. 0 se e' tornato da solo, 1 se il banco l'ha interrotto al limite */
static int walk(bool check_only, bool *conteso, int *ret, int *fault, uint64_t *gpa)
{
	*gpa = 0; *fault = -1; *ret = -1;
	if (conteso != NULL)
		*conteso = false;
	if (setjmp(salto) != 0)
		return (1);
	*ret = _vm_gla2gpa(&vc, &pg, GLA, VM_PROT_RW, gpa, fault, check_only, conteso);
	return (0);
}

/* _vm_copy_setup sotto la stessa guardia di walk(): 1 se il banco l'ha interrotto al limite */
static int copia(struct vm_copyinfo *ci, bool *conteso, int *ret, int *fault)
{
	*fault = -1; *ret = -1;
	if (setjmp(salto) != 0)
		return (1);
	*ret = _vm_copy_setup(&vc, &pg, GLA, 8, VM_PROT_RW, ci, 2, fault, conteso);
	return (0);
}

static bool ad_completi(void)
{
	for (int i = 0; i < 4; i++)
		if ((*voce[i] & PG_A) == 0)
			return (false);
	return ((*voce[3] & PG_M) != 0);
}

int main(int argc, char **argv)
{
	const char *albero = argc > 1 ? argv[1] : "?";
	int ret, fault, interrotto;
	bool conteso;
	uint64_t gpa;
	struct vm_copyinfo ci[2];

	printf("banco P3 stadio 11 (%s)\n", albero);

	/* --- L: i chiamanti legacy, invariati */
	tabelle();
	interrotto = walk(false, NULL, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && gpa == GPA_ATTESO && ad_completi() && ripartenze == 0 && holds_attivi == 0,
	    "L0 ret %d fault %d ripartenze %ld holds %ld", ret, fault, ripartenze, holds_attivi);
	tabelle(); avv_cas = 1000;
	interrotto = walk(false, NULL, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && ad_completi() && ripartenze == 1000 && gla2gpa_restart_capped == 0,
	    "L1 legacy, 1000 corse perse (oltre il limite): ret %d ripartenze %ld capped %lu", ret, ripartenze, gla2gpa_restart_capped);
	tabelle(); avv_cas = -1;
	interrotto = walk(false, NULL, &ret, &fault, &gpa);
	VERO(interrotto && ripartenze >= limite_ripartenze && gla2gpa_restart_capped == 0,
	    "L2 legacy, contesa persistente: interrotto %d ripartenze %ld (P3 resta per i chiamanti non migrati)", interrotto, ripartenze);
	INFO("L: i chiamanti legacy (vm_gla2gpa) non vedono il limite: 1000 corse perse finiscono, la contesa persistente non torna");
	tabelle(); avv_cas = -1;
	interrotto = walk(true, NULL, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && ripartenze == 0 && cas_tentati == 0, "L3 check_only: ripartenze %ld", ripartenze);

	/* --- B: i chiamanti migrati */
	tabelle(); avv_cas = -1;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && conteso && ripartenze == 64 && gla2gpa_restart_capped == 1 &&
	    iniezioni_pf == 0 && iniezioni_gp == 0 && eventi_nested == 0 && ripartenze_istruzione == 0 && holds_attivi == 0,
	    "B1 contesa persistente: interrotto %d ret %d fault %d conteso %d ripartenze %ld capped %lu pf %ld rip.istr %ld holds %ld",
	    interrotto, ret, fault, conteso, ripartenze, gla2gpa_restart_capped, iniezioni_pf, ripartenze_istruzione, holds_attivi);
	INFO("B1: contesa persistente -> CONTESO dopo %ld ripartenze: ret 0, fault 0, nessuna pagina tenuta, nessuna eccezione", ripartenze);
	tabelle(); avv_cas = 10;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && !conteso && gpa == GPA_ATTESO && ad_completi() && ripartenze == 10,
	    "B2 10 corse perse: ret %d conteso %d ripartenze %ld A/D %d", ret, conteso, ripartenze, ad_completi());
	tabelle(); avv_cas = 64;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && !conteso && ad_completi() && ripartenze == 64 && gla2gpa_restart_capped == 0,
	    "B3 bordo: 64 corse perse (= il limite) finiscono bene: conteso %d ripartenze %ld", conteso, ripartenze);
	tabelle(); avv_cas = 65;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && conteso && ripartenze == 64 && gla2gpa_restart_capped == 1,
	    "B4 bordo: 65 corse perse -> CONTESO dopo 64 ripartenze: conteso %d ripartenze %ld", conteso, ripartenze);
	tabelle(); avv_ept = -1;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && conteso && ripartenze == 64 && eventi_nested == 0 && holds_attivi == 0,
	    "B5 EPT12 instabile per sempre: conteso %d ripartenze %ld eventi %ld holds %ld", conteso, ripartenze, eventi_nested, holds_attivi);
	tabelle(); avv_ept = 7;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && !conteso && ad_completi() && ripartenze == 7 && ept_eagain == 7,
	    "B6 EPT12 cambiata 7 volte: conteso %d ripartenze %ld", conteso, ripartenze);
	tabelle(); gla2gpa_restart_max = 0; avv_cas = -1;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(interrotto && !conteso && gla2gpa_restart_capped == 0,
	    "B7 limite 0 = nessun limite anche per i migrati: interrotto %d conteso %d", interrotto, conteso);
	tabelle(); gla2gpa_restart_max = 1; avv_cas = -1;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && conteso && ripartenze == 1, "B8 limite 1 = una ripartenza concessa: conteso %d ripartenze %ld", conteso, ripartenze);
	tabelle(); gla2gpa_restart_max = 1; avv_cas = 1;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && !conteso && ad_completi() && ripartenze == 1, "B8b limite 1, una corsa persa finisce bene: conteso %d", conteso);
	/* il #PF vero resta un #PF, anche coi migrati */
	tabelle(); *voce[3] = 0;
	interrotto = walk(false, &conteso, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 1 && !conteso && iniezioni_pf == 1 && holds_attivi == 0,
	    "B9 #PF vero: fault %d conteso %d pf %ld", fault, conteso, iniezioni_pf);

	/* --- C: _vm_copy_setup (vmm.c), la via di nested_operand_copy: su CONTESO nessuna pagina tenuta */
	tabelle(); avv_cas = -1;
	memset(ci, 0x5a, sizeof(ci)); conteso = false;
	interrotto = copia(ci, &conteso, &ret, &fault);
	VERO(!interrotto && ret == 0 && fault == 0 && conteso && holds_attivi == 0 && ci[0].hva == NULL && ci[0].cookie == NULL &&
	    ci[1].hva == NULL && gla2gpa_restart_capped == 1,
	    "C1 copia con contesa persistente: ret %d fault %d conteso %d holds %ld hva %p", ret, fault, conteso,
	    holds_attivi, ci[0].hva);
	tabelle(); avv_cas = 10;
	conteso = true;
	interrotto = copia(ci, &conteso, &ret, &fault);
	VERO(!interrotto && ret == 0 && fault == 0 && !conteso && holds_attivi == 1 && ci[0].hva == mem + GPA_ATTESO && ci[0].len == 8,
	    "C2 copia con 10 corse perse: ret %d conteso %d holds %ld", ret, conteso, holds_attivi);
	vm_copy_teardown(ci, 2);
	VERO(holds_attivi == 0, "C2 teardown: holds %ld", holds_attivi);
	tabelle(); avv_cas = 1000;
	interrotto = copia(ci, NULL, &ret, &fault);
	VERO(!interrotto && ret == 0 && fault == 0 && holds_attivi == 1 && ripartenze == 1000 && gla2gpa_restart_capped == 0,
	    "C3 copia legacy (vm_copy_setup), 1000 corse perse: ret %d holds %ld ripartenze %ld", ret, holds_attivi, ripartenze);
	vm_copy_teardown(ci, 2);

	VERO(kassert_fallite == 0, "KASSERT fallite %d", kassert_fallite);
	printf("%s: %d ok, %d errati\n", albero, nok, nf);
	return (nf != 0);
}
