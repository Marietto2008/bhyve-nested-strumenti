/*
 * banco.c -- Claude 30/10/2026, parere #155 (P3). Esercita la funzione VERA _vm_gla2gpa (funzioni.inc, estratta da
 * run.sh) di un clone contro l'avversario di stub.h. Walk a 4 livelli, scrittura (prot RW): l'emulatore deve
 * accendere A in tutti i livelli e D nella foglia. Misura le ripartenze del walk e verifica l'esito.
 * Uso: banco <nome-albero> [contesa-thread]
 */
#include "stub.h"
#include "funzioni.inc"

static int nf, nok;
#define VERO(c, ...) do { if (c) { nok++; } else { nf++; printf("  ERRATO  "); printf(__VA_ARGS__); printf("  [%s]\n", #c); } } while (0)
#define INFO(...) do { printf("  info    "); printf(__VA_ARGS__); printf("\n"); } while (0)

/* pagine: 1 PML4, 2 PDPT, 3 PD, 4 PT, 5 dato. GLA 0x400123: indici 0/0/2/0, scostamento 0x123 */
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
	pml4[0] = 2 * PAGE_SIZE | PG_V | PG_RW | PG_U;		/* A/D a zero: l'emulatore deve accenderli */
	pdpt[0] = 3 * PAGE_SIZE | PG_V | PG_RW | PG_U;
	pd[2] = 4 * PAGE_SIZE | PG_V | PG_RW | PG_U;
	pt[0] = 5 * PAGE_SIZE | PG_V | PG_RW | PG_U;
	voce[0] = &pml4[0]; voce[1] = &pdpt[0]; voce[2] = &pd[2]; voce[3] = &pt[0];
	pg.cr3 = 1 * PAGE_SIZE; pg.cpl = 0; pg.cpu_mode = CPU_MODE_64BIT; pg.paging_mode = PAGING_MODE_64;
	ripartenze = cas_tentati = cas_sabotati = ept_eagain = 0;
	iniezioni_pf = iniezioni_gp = ripartenze_istruzione = eventi_nested = 0;
	avv_cas = avv_ept = 0;
	nega_finale = 0;
}

/* un walk; ritorna 0 se e' tornato da solo, 1 se il banco l'ha dovuto interrompere al limite */
static int walk(bool check_only, int *ret, int *fault, uint64_t *gpa)
{
	*gpa = 0; *fault = -1; *ret = -1;
	if (setjmp(salto) != 0)
		return (1);
	*ret = _vm_gla2gpa(&vc, &pg, GLA, VM_PROT_RW, gpa, fault, check_only);
	return (0);
}

/*
 * #156 §3: oracolo del CONTRATTO di vm_gla2gpa (commit FreeBSD d3956e46736f): ret 0 e fault 0 = tradotto; ret 0 e
 * fault 1 = eccezione INIETTATA (qui: #PF o #GP) oppure, nel nested, violazione EPT12 registrata per l'L1 (H2):
 * ESATTAMENTE una causa; EFAULT = errore dell'host. In check_only fault 1 non deve avere NESSUN effetto.
 */
static const char *contratto(bool check_only, int ret, int fault)
{
	long cause = iniezioni_pf + iniezioni_gp + eventi_nested;
	if (ret == EFAULT)
		return ("HOST_FATALE");
	if (ret != 0)
		return ("CODICE_IGNOTO");
	if (check_only)
		return (fault == 0 || (cause == 0 && ripartenze_istruzione == 0) ? "OK" : "NOFAULT_CON_EFFETTI");
	if (fault == 0)
		return (cause == 0 ? "OK" : "TRADOTTO_CON_CAUSA");
	return (cause == 1 ? "OK" : (cause == 0 ? "FAULT_SENZA_CAUSA" : "CAUSE_MULTIPLE"));
}

static bool ad_completi(void)
{
	for (int i = 0; i < 4; i++)
		if ((*voce[i] & PG_A) == 0)
			return (false);
	return ((*voce[3] & PG_M) != 0);
}

/* contesa vera: un thread che riscrive la foglia (bit 9) senza sosta */
static volatile int fermo;
static void *martello(void *a)
{
	(void)a;
	while (!fermo)
		__sync_fetch_and_xor(voce[3], 0x200ul);
	return (NULL);
}

int main(int argc, char **argv)
{
	const char *albero = argc > 1 ? argv[1] : "?";
	bool nested = strstr(albero, "nested") != NULL;
	/* ripartenze che il walk fa DA SOLO, senza avversario. Base (FreeBSD originale): una, quando la foglia vuole A e
	 * D: il cmpset di A non aggiorna la copia locale 'pte' e il cmpset di D, che si aspetta ancora A=0, fallisce.
	 * Nested (H2-AD): A e D della stessa voce sono un solo CAS (ptp_pend_add), quindi nessuna. */
	long auto_rip = nested ? 0 : 1, cas_s0 = nested ? 4 : 6;
	int ret, fault, interrotto;
	uint64_t gpa;

	printf("banco P3 (%s)\n", albero);

	/* S0: nessun avversario: nessuna ripartenza, A/D accesi, GPA giusto */
	tabelle();
	interrotto = walk(false, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && gpa == GPA_ATTESO && ad_completi() && ripartenze == auto_rip &&
	    cas_tentati == cas_s0, "S0 ret %d fault %d gpa %#lx A/D %d ripartenze %ld (attese %ld) cmpset %ld (attesi %ld)",
	    ret, fault, (u_long)gpa, ad_completi(), ripartenze, auto_rip, cas_tentati, cas_s0);
	INFO("S0: senza avversario %ld ripartenza/e e %ld cmpset", ripartenze, cas_tentati);

	/* S1: K corse perse: K ripartenze esatte, poi il walk finisce bene (il progresso dipende SOLO dall'esterno) */
	for (long k = 1; k <= 1000; k *= 10) {
		tabelle(); avv_cas = k;
		interrotto = walk(false, &ret, &fault, &gpa);
		VERO(!interrotto && ret == 0 && fault == 0 && gpa == GPA_ATTESO && ad_completi() && ripartenze == k + auto_rip &&
		    iniezioni_pf == 0 && ripartenze_istruzione == 0,
		    "S1 k=%ld ret %d fault %d ripartenze %ld A/D %d pf %ld", k, ret, fault, ripartenze, ad_completi(), iniezioni_pf);
	}
	INFO("S1: con K corse perse il walk riparte esattamente K (+%ld propria) volte e poi finisce", auto_rip); INFO("S1: (nessun errore, nessun #PF, nessun EFAULT)");

	/* S2: avversario persistente sul cmpset: il walk NON torna da solo */
	tabelle(); avv_cas = -1;
	interrotto = walk(false, &ret, &fault, &gpa);
	VERO(interrotto && ripartenze >= limite_ripartenze && iniezioni_pf == 0 && ripartenze_istruzione == 0,
	    "S2 interrotto %d ripartenze %ld", interrotto, ripartenze);
	INFO("S2: cmpset perso per sempre -> %ld ripartenze senza ritorno (fermato dal banco); nessun controllo di segnali o sospensione nel ciclo", ripartenze);

	/* S3: lo stesso avversario in check_only (vm_gla2gpa_nofault): nessuna scrittura A/D, quindi nessuna ripartenza */
	tabelle(); avv_cas = -1;
	interrotto = walk(true, &ret, &fault, &gpa);
	VERO(!interrotto && ret == 0 && fault == 0 && ripartenze == 0 && cas_tentati == 0,
	    "S3 interrotto %d ret %d ripartenze %ld cas %ld", interrotto, ret, ripartenze, cas_tentati);
	INFO("S3: check_only non ripete mai: il problema riguarda solo il walk che scrive A/D");

	if (nested) {
		/* S4: l'L1 cambia EPT12 K volte fra lettura e scrittura degli A/D (EAGAIN): K ripartenze, poi finisce */
		tabelle(); avv_ept = 7;
		interrotto = walk(false, &ret, &fault, &gpa);
		VERO(!interrotto && ret == 0 && fault == 0 && ad_completi() && ripartenze == 7 + auto_rip && ept_eagain == 7,
		    "S4 ret %d ripartenze %ld eagain %ld", ret, ripartenze, ept_eagain);
		/* S5: EPT12 instabile per sempre: il walk non torna */
		tabelle(); avv_ept = -1;
		interrotto = walk(false, &ret, &fault, &gpa);
		VERO(interrotto && ripartenze >= limite_ripartenze && !ad_completi(),
		    "S5 interrotto %d ripartenze %ld", interrotto, ripartenze);
		INFO("S5: EPT12 cambiata per sempre -> %ld ripartenze senza ritorno; nessuna A/D scritta (fase 2 di H2-AD mai raggiunta)", ripartenze);
	}

	/* S6 (informativo): contesa vera con un thread che riscrive la foglia senza sosta */
	if (argc > 2) {
		pthread_t t;
		long mx = 0, tot = 0, n = 20000, lunghi = 0;
		tabelle();
		fermo = 0;
		pthread_create(&t, NULL, martello, NULL);
		for (long i = 0; i < n; i++) {
			for (int j = 0; j < 4; j++)
				__sync_fetch_and_and(voce[j], ~(uint64_t)(PG_A | PG_M));
			ripartenze = 0;
			if (walk(false, &ret, &fault, &gpa) == 0 && ret == 0) {
				tot += ripartenze;
				if (ripartenze > mx) mx = ripartenze;
				if (ripartenze >= 100) lunghi++;
			}
		}
		fermo = 1;
		pthread_join(t, NULL);
		INFO("S6 contesa vera (un thread martella la foglia): %ld walk, ripartenze medie %.2f, massimo %ld, walk con >=100 ripartenze %ld",
		    n, (double)tot / n, mx, lunghi);
	}

	/* #156: il contratto vale sui casi AUTENTICI: #PF (foglia non presente), #GP (GLA non canonico), nested: EPT12
	 * che nega l'accesso finale (evento registrato, istruzione ripartita) */
	tabelle(); *voce[3] &= ~(uint64_t)PG_V;
	interrotto = walk(false, &ret, &fault, &gpa);
	VERO(!interrotto && fault == 1 && iniezioni_pf == 1 && strcmp(contratto(false, ret, fault), "OK") == 0,
	    "S7 #PF autentico: fault %d pf %ld contratto %s", fault, iniezioni_pf, contratto(false, ret, fault));
	{
		uint64_t g0 = gpa;
		(void)g0;
		tabelle();
		if (setjmp(salto) == 0)
			ret = _vm_gla2gpa(&vc, &pg, 0x0000900000000000UL, VM_PROT_RW, &gpa, &fault, false);
		VERO(fault == 1 && iniezioni_gp == 1 && strcmp(contratto(false, ret, fault), "OK") == 0,
		    "S8 #GP autentico: fault %d gp %ld contratto %s", fault, iniezioni_gp, contratto(false, ret, fault));
	}
	if (nested) {
		tabelle(); nega_finale = 1;
		interrotto = walk(false, &ret, &fault, &gpa);
		VERO(!interrotto && fault == 1 && eventi_nested == 1 && ripartenze_istruzione == 1 &&
		    strcmp(contratto(false, ret, fault), "OK") == 0 && (*voce[3] & (PG_A | PG_M)) == 0,
		    "S9 EPT12 nega il finale: fault %d eventi %ld restart %ld contratto %s A/D foglia %#lx", fault,
		    eventi_nested, ripartenze_istruzione, contratto(false, ret, fault), (u_long)(*voce[3] & (PG_A | PG_M)));
		tabelle(); nega_finale = 1;
		interrotto = walk(true, &ret, &fault, &gpa);
		VERO(!interrotto && ret == EFAULT && eventi_nested == 0 && ripartenze_istruzione == 0,
		    "S9n nofault con EPT12 che nega: ret %d eventi %ld restart %ld", ret, eventi_nested, ripartenze_istruzione);
	}
	/* contratto anche sui casi gia' visti: tradotto senza cause */
	tabelle(); walk(false, &ret, &fault, &gpa);
	VERO(strcmp(contratto(false, ret, fault), "OK") == 0, "S0c contratto %s", contratto(false, ret, fault));
#ifdef MUTANTE_CODIFICA_RESPINTA
	/* #156 §3, test NEGATIVO: la codifica del mio rapporto P3 (dopo N ripartenze vm_restart_instruction + fault=1,
	 * nessuna eccezione, nessun evento). Il walk ora torna, ma l'oracolo del contratto DEVE rifiutarla */
	tabelle(); avv_cas = -1;
	interrotto = walk(false, &ret, &fault, &gpa);
	printf("MUTANTE: interrotto %d ret %d fault %d pf %ld gp %ld eventi %ld restart %ld ripartenze %ld contratto %s\n",
	    interrotto, ret, fault, iniezioni_pf, iniezioni_gp, eventi_nested, ripartenze_istruzione, ripartenze,
	    contratto(false, ret, fault));
	VERO(strcmp(contratto(false, ret, fault), "FAULT_SENZA_CAUSA") == 0, "MUTANTE: contratto %s (atteso FAULT_SENZA_CAUSA)",
	    contratto(false, ret, fault));
#endif
	VERO(kassert_fallite == 0, "KASSERT fallite %d", kassert_fallite);
	printf("%s: %d ok, %d errati\n", albero, nok, nf);
	return (nf != 0);
}
