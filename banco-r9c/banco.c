/* banco.c -- Claude 31/10/2026, stadio 10, unita' R9 + chiamanti. Esegue le funzioni VERE estratte da un albero
 * (vie_calculate_gla, get_gla per MOVS/STOS, emulate_stack_op per PUSH/POP) contro l'oracolo dell'SDM (vol. 3A,
 * Limit Checking; vol. 1, stack). Compilato con -ftrivial-auto-var-init=pattern: la memoria di stack NON inizializzata
 * ha un contenuto deterministico (0xAA..), cosi' l'uso di un descrittore non letto e' riproducibile.
 * Oracolo per caso: eccezione attesa (nessuna/#SS/#GP), indirizzo lineare, nessun KASSERT (nel kernel = panic). */
#include "stub.h"
#include "estratte.c"
static int nok, nko;
static int rd(struct vcpu *v, uint64_t g, uint64_t *x, int s, void *a) { (void)v; (void)g; (void)s; (void)a; *x = 0; return (0); }
static int wr(struct vcpu *v, uint64_t g, uint64_t x, int s, void *a) { (void)v; (void)g; (void)x; (void)s; (void)a; return (0); }
static void azzera(void) { memset(g_reg, 0, sizeof(g_reg)); memset(g_seg, 0, sizeof(g_seg)); g_getseg_ss = g_inj_ss = g_inj_gp =
	g_inj_ac = g_copy = g_copy_len = 0; g_copy_gla = 0; kassert_falliti = 0; }
/* atteso: 'N' nessuna eccezione, 'S' #SS, 'G' #GP */
static void esito(const char *nome, const char *classe, char att, uint64_t gla_att, uint64_t gla_oss, int copia)
{
	char oss = g_inj_ss ? 'S' : g_inj_gp ? 'G' : 'N';
	int ok = oss == att && kassert_falliti == 0 && (att != 'N' || gla_oss == gla_att) && (att == 'N' || !copia || !g_copy);
	nok += ok; nko += !ok;
	printf("  %s %-46s %-6s atteso %c%s osservato %c gla %#llx KASSERT falliti %d lettura SS %d\n", ok ? "ok    " : "ERRATO",
	    nome, classe, att, att == 'N' ? "" : "", oss, (unsigned long long)gla_oss, kassert_falliti, g_getseg_ss);
}
static void pila(const char *nome, const char *classe, enum vm_cpu_mode modo, struct seg_desc ss, uint64_t rsp, int push,
    int opsize, char att, uint64_t gla_att)
{
	struct vie vie = { .opsize = opsize, .opsize_override = 0, .reg = 6,
	    .op = { .op_type = push ? VIE_OP_TYPE_PUSH : VIE_OP_TYPE_POP } };
	struct vm_guest_paging pg = { .cr3 = 0, .cpl = 0, .cpu_mode = modo, .paging_mode = 0 };
	struct vcpu v;
	azzera();
	g_seg[VM_REG_GUEST_SS] = ss;
	g_reg[VM_REG_GUEST_RSP] = rsp;
	(void)emulate_stack_op(&v, 0xfee00000, &vie, &pg, rd, wr, NULL);
	esito(nome, classe, att, gla_att, g_copy_gla, 1);
}
static void stringa(const char *nome, const char *classe, enum vm_cpu_mode modo, struct seg_desc ds, uint64_t si, int opsize,
    int asz, char att, uint64_t gla_att)
{
	struct vie vie = { .opsize = opsize };
	struct vm_guest_paging pg = { .cr3 = 0, .cpl = 0, .cpu_mode = modo, .paging_mode = 0 };
	struct vcpu v;
	uint64_t gla = 0;
	int fault = -1;
	azzera();
	g_seg[VM_REG_GUEST_DS] = ds;
	g_reg[VM_REG_GUEST_RSI] = si;
	(void)get_gla(&v, &vie, &pg, opsize, asz, PROT_READ, VM_REG_GUEST_DS, VM_REG_GUEST_RSI, &gla, &fault);
	esito(nome, classe, att, gla_att, gla, 0);
}
int main(void)
{
	/* descrittori: 0x93 dati RW presenti (expand-up), 0x97 dati RW expand-down; bit 14 (0x4000) = B/D */
	struct seg_desc reale = { 0x20000, 0xffff, 0x93 }, p16 = { 0x30000, 0xffff, 0x93 },
	    piatto32 = { 0, 0xffffffff, 0x4093 }, giu32 = { 0, 0x0fff, 0x4097 }, giu_vuoto = { 0, 0xffffffff, 0x4097 },
	    nonpiatto32 = { 0x1000, 0xffffffff, 0x4093 }, s64 = { 0, 0, 0 },
	    giu16 = { 0x40000, 0x0fff, 0x0097 };	/* expand-down con B=0: offset validi 0x1000..0xffff (parere Opus) */
	printf("pila (emulate_stack_op)\n");
	pila("reale PUSH word, SP 0x100", "SDM", CPU_MODE_REAL, reale, 0x100, 1, 2, 'N', 0x200fe);
	pila("reale POP word, SP 0xfffe", "SDM", CPU_MODE_REAL, reale, 0xfffe, 0, 2, 'N', 0x2fffe);
	pila("reale PUSH word, SP 0x1 (word a 0xffff)", "SDM", CPU_MODE_REAL, reale, 0x1, 1, 2, 'S', 0);
	pila("16 bit PUSH word, SP 0x1 (word a 0xffff)", "SDM", CPU_MODE_PROTECTED, p16, 0x1, 1, 2, 'S', 0);
	pila("16 bit PUSH word, SP 0x100", "SDM", CPU_MODE_PROTECTED, p16, 0x100, 1, 2, 'N', 0x300fe);
	pila("32 bit piatto PUSH dword, ESP 0x1000", "SDM", CPU_MODE_PROTECTED, piatto32, 0x1000, 1, 4, 'N', 0xffc);
	pila("expand-down lim 0xfff, ESP 0x1004", "SDM", CPU_MODE_PROTECTED, giu32, 0x1004, 1, 4, 'N', 0x1000);
	pila("expand-down lim 0xfff, ESP 0x1002 (byte 0xffe)", "SDM", CPU_MODE_PROTECTED, giu32, 0x1002, 1, 4, 'S', 0);
	pila("expand-down lim 0xfff, ESP 0x1003 (byte 0xfff = limite)", "SDM", CPU_MODE_PROTECTED, giu32, 0x1003, 1, 4, 'S', 0);
	pila("expand-down lim 0xffffffff (vuoto), ESP 0x2000", "SDM", CPU_MODE_PROTECTED, giu_vuoto, 0x2000, 1, 4, 'S', 0);
	pila("expand-down B=0 lim 0xfff, SP 0x2000", "SDM", CPU_MODE_PROTECTED, giu16, 0x2000, 1, 2, 'N', 0x41ffe);
	pila("expand-down B=0 lim 0xfff, SP 0x1 (word a 0xffff)", "SDM", CPU_MODE_PROTECTED, giu16, 0x1, 1, 2, 'S', 0);
	pila("64 bit PUSH qword, RSP 0x7fff0010", "SDM", CPU_MODE_64BIT, s64, 0x7fff0010, 1, 8, 'N', 0x7fff0008);
	pila("64 bit POP, RSP non canonico", "SDM", CPU_MODE_64BIT, s64, 0x0000800000000000ULL, 0, 8, 'S', 0);
	printf("stringhe (get_gla: MOVS/STOS/LODS)\n");
	stringa("16 bit word a 0xffff", "SDM", CPU_MODE_PROTECTED, p16, 0xffff, 2, 2, 'G', 0);
	stringa("16 bit word a 0xfffe", "SDM", CPU_MODE_PROTECTED, p16, 0xfffe, 2, 2, 'N', 0x3fffe);
	stringa("reale word a 0xffff", "SDM", CPU_MODE_REAL, reale, 0xffff, 2, 2, 'G', 0);
	stringa("32 bit piatto, dword a 0xfffffffe", "POLICY", CPU_MODE_PROTECTED, piatto32, 0xfffffffe, 4, 4, 'N', 0xfffffffe);
	stringa("32 bit non piatto lim 0xffffffff, dword a 0xfffffffe", "POLICY", CPU_MODE_PROTECTED, nonpiatto32, 0xfffffffe, 4, 4, 'G', 0);
	stringa("expand-down B=0 lim 0xfff, word a 0xfffe", "SDM", CPU_MODE_PROTECTED, giu16, 0xfffe, 2, 2, 'N', 0x4fffe);
	stringa("expand-down B=0 lim 0xfff, word a 0xffff", "SDM", CPU_MODE_PROTECTED, giu16, 0xffff, 2, 2, 'G', 0);
	stringa("64 bit qword a 0x1000", "SDM", CPU_MODE_64BIT, s64, 0x1000, 8, 8, 'N', 0x1000);
	printf("SUMMARY: %d ok, %d errati\n", nok, nko);
	return (nko != 0);
}
