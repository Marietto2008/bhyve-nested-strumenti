/* banco.c -- Claude 31/10/2026, #169 R3. opnd_stato() VERA (estratta) con ogni operazione sul VMCS fatta fallire a
 * turno: dopo il fallimento NESSUNA operazione successiva (oracolo: il diario deve essere esattamente il prefisso
 * fino all'operazione fallita, piu' le sole letture del controllo stesso), esito falso, una riga PREREQ, fermo. */
#include "stub.h"
#include "estratte.c"
static int nok, nko;
static void esito(int ok, const char *m) { if (ok) nok++; else nko++; printf("  %s %s\n", ok ? "ok    " : "ERRATO", m); }
static void azzera(int f, bool usato) {
	diario[0] = 0; nop = 0; falli = f; opnd_err = 0; opnd_fermo = false; opnd_tmp_usato = usato; memset_tmp = 0;
	corrente_fittizia = 1;
}
int main(void)
{
	const char *completo = "CLEAR MEMSET CLEAR LOAD WRITE READ CLEAR PTRST LOAD PTRST ";
	/* prefisso atteso del diario quando fallisce l'operazione k (1-based) del percorso completo */
	const char *ops[] = { "CLEAR", "MEMSET", "CLEAR", "LOAD", "WRITE", "READ", "CLEAR", "PTRST", "LOAD", "PTRST" };
	char atteso[512], m[700];
	int k, n = 10;
	bool r;

	azzera(0, true); r = opnd_stato();
	snprintf(m, sizeof m, "percorso completo: esito %d, diario '%s'", r, diario);
	esito(r && !strcmp(diario, completo) && opnd_err == 0 && !opnd_fermo, m);
	for (k = 1; k <= n; k++) {
		if (!strcmp(ops[k - 1], "MEMSET"))
			continue;		/* memset non fallisce */
		azzera(k, true); r = opnd_stato();
		atteso[0] = 0;
		for (int i = 0; i < k; i++) { strcat(atteso, ops[i]); strcat(atteso, " "); }
		snprintf(m, sizeof m, "fallisce %d (%s): esito %d fermo %d PREREQ %d diario '%s' atteso '%s'", k, ops[k - 1],
		    r, opnd_fermo, opnd_err, diario, atteso);
		esito(!r && opnd_fermo && opnd_err == 1 && !strcmp(diario, atteso), m);
	}
	/* CLEAR prima del riuso fallito: la regione NON si azzera */
	azzera(1, true); (void)opnd_stato();
	esito(memset_tmp == 0, "CLEAR prima del riuso fallito: nessun memset del VMCS di lavoro");
	/* LOAD del VMCS di lavoro fallito: nessuna VMWRITE */
	azzera(4, true); (void)opnd_stato();
	esito(strstr(diario, "WRITE") == NULL, "VMPTRLD fallito: nessuna VMWRITE");
	/* dopo un fermo, opnd_stato non fa NULLA */
	azzera(1, true); (void)opnd_stato(); diario[0] = 0; falli = 0; r = opnd_stato();
	esito(!r && diario[0] == 0, "dopo il fermo: esito falso e nessuna operazione");
	/* primo uso (nessun CLEAR di riuso) */
	azzera(0, false); r = opnd_stato();
	esito(r && !strcmp(diario, "MEMSET CLEAR LOAD WRITE READ CLEAR PTRST LOAD PTRST "), "primo uso: niente CLEAR di riuso");
	/* opnd_carica */
	azzera(1, true); r = opnd_carica(opnd_cur, "prova");
	esito(!r && opnd_fermo && opnd_err == 1, "opnd_carica fallita: esito falso, fermo, PREREQ");
	azzera(0, true); r = opnd_carica(opnd_cur, "prova");
	esito(r && !opnd_fermo && opnd_err == 0, "opnd_carica riuscita");
	printf("SUMMARY: %d ok, %d errati\n", nok, nko);
	return nko != 0;
}
