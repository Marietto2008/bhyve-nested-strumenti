/*
 * r9b.c -- Claude 31/10/2026, parere #165 §3: vie_calculate_gla PRIMA (r5) e DOPO (ramo R9) nello stesso programma,
 * contro l'oracolo SDM (vol. 3A 6.3) e la regola di progetto (b) per la zona implementation-specific (limite
 * effettivo FFFFFFFFH): esenzione solo per il segmento piatto (base 0, limite 0xffffffff, codice o dati expand-up).
 * Classi: SDM = esito determinato dall'SDM; POLICY = esito scelto con la (b). Uso: r9b <albero>
 */
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#define KASSERT(c, m)	do { if (!(c)) { printf("KASSERT FALLITA: %s\n", #c); kassert++; } } while (0)
#define PROT_READ	1
#define PROT_WRITE	2
#define SEG_DESC_TYPE(access)		((access) & 0x001f)
#define SEG_DESC_PRESENT(access)	(((access) & 0x0080) ? 1 : 0)
#define SEG_DESC_DEF32(access)		(((access) & 0x4000) ? 1 : 0)
#define SEG_DESC_UNUSABLE(access)	(((access) & 0x10000) ? 1 : 0)
static int kassert;
enum vm_cpu_mode { CPU_MODE_REAL, CPU_MODE_PROTECTED, CPU_MODE_COMPATIBILITY, CPU_MODE_64BIT };
enum vm_reg_name { VM_REG_GUEST_ES, VM_REG_GUEST_CS, VM_REG_GUEST_SS, VM_REG_GUEST_DS, VM_REG_GUEST_FS,
	VM_REG_GUEST_GS };
struct seg_desc { uint64_t base; uint32_t limit; uint32_t access; };

#include "vie-prima.inc"
#include "vie-dopo.inc"

struct caso { const char *nome; enum vm_cpu_mode modo; int asz; uint64_t base; uint32_t limit, acc; uint64_t ea;
	int len; };

/* 0 lecito, 1 fuori; *cl = "SDM" o "POLICY" */
static int
atteso(const struct caso *c, const char **cl)
{
	uint64_t primo = c->ea, ultimo = c->ea + c->len - 1, alto;
	uint32_t t = c->acc & 0x1f;

	*cl = "SDM";
	if (c->modo == CPU_MODE_64BIT)
		return (0);				/* nessun controllo di limite in modo 64 bit */
	if ((t & 0xc) == 0x4) {				/* dati expand-down: nessuna esenzione */
		alto = (c->acc & 0x4000) ? 0xffffffffULL : 0xffffULL;
		if (ultimo > alto && alto == 0xffffffffULL)
			*cl = "POLICY";
		return (primo <= c->limit || ultimo > alto);
	}
	if (ultimo > c->limit && c->limit == 0xffffffffU) {
		*cl = "POLICY";
		return (c->base != 0);			/* (b): piatto esente, base non nulla no */
	}
	return (ultimo > c->limit);
}

int
main(int argc, char **argv)
{
	static const struct caso cs[] = {
		{ "16b exp-up lim 0xffff, word a 0xffff (MOVSW SI=0xffff)", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xffff, 2 },
		{ "16b exp-up lim 0xffff, dword a 0xfffe", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xfffe, 4 },
		{ "16b exp-up lim 0xffff, dword a 0xfffd", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xfffd, 4 },
		{ "16b exp-up lim 0xffff, byte a 0xffff", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xffff, 1 },
		{ "16b exp-up lim 0xfffff, word a 0xffff (67h)", CPU_MODE_PROTECTED, 2, 0, 0xfffff, 0x4093, 0xffff, 2 },
		{ "16b exp-down B=1 lim 0x0fff, dword a 0xfffe", CPU_MODE_PROTECTED, 2, 0, 0x0fff, 0x4097, 0xfffe, 4 },
		{ "16b exp-down B=1 lim 0xfffe, word a 0xffff (#165 §3)", CPU_MODE_PROTECTED, 2, 0, 0xfffe, 0x4097, 0xffff, 2 },
		{ "16b exp-down B=1 lim 0xfffe, word a 0xfffe", CPU_MODE_PROTECTED, 2, 0, 0xfffe, 0x4097, 0xfffe, 2 },
		{ "16b exp-down B=0 lim 0x0fff, dword a 0xfffe", CPU_MODE_PROTECTED, 2, 0, 0x0fff, 0x0097, 0xfffe, 4 },
		{ "16b SS exp-up lim 0xffff, word a 0xffff (PUSH)", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xffff, 2 },
		{ "32b seg, indirizzi a 16, lim 0xffff, dword a 0xffff", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x4093, 0xffff, 4 },
		{ "32b exp-down B=1 lim 0x0fff, dword a 0xfffffffe", CPU_MODE_PROTECTED, 4, 0, 0x0fff, 0xc097, 0xfffffffeULL, 4 },
		{ "32b exp-down B=1 lim 0xffffffff (vuoto), byte a 0x1000", CPU_MODE_PROTECTED, 4, 0, 0xffffffffU, 0xc097, 0x1000, 1 },
		{ "32b piatto base 0, dword a 0xfffffffe", CPU_MODE_PROTECTED, 4, 0, 0xffffffffU, 0xc093, 0xfffffffeULL, 4 },
		{ "32b codice piatto base 0, dword a 0xfffffffe", CPU_MODE_PROTECTED, 4, 0, 0xffffffffU, 0xc09b, 0xfffffffeULL, 4 },
		{ "32b lim 0xffffffff base 0x1000, dword a 0xfffffffe", CPU_MODE_PROTECTED, 4, 0x1000, 0xffffffffU, 0xc093, 0xfffffffeULL, 4 },
		{ "32b lim 0x7fffffff, dword a 0x7ffffffe", CPU_MODE_PROTECTED, 4, 0, 0x7fffffff, 0xc093, 0x7ffffffe, 4 },
		{ "32b lim 0x7fffffff, dword a 0x7ffffffc", CPU_MODE_PROTECTED, 4, 0, 0x7fffffff, 0xc093, 0x7ffffffc, 4 },
		{ "modo reale lim 0xffff, word a 0xffff", CPU_MODE_REAL, 2, 0, 0xffff, 0x0093, 0xffff, 2 },
		{ "modo reale lim 0xffff, dword a 0xfffe", CPU_MODE_REAL, 2, 0, 0xffff, 0x0093, 0xfffe, 4 },
		{ "modo reale lim 0xffff, word a 0xfffe", CPU_MODE_REAL, 2, 0, 0xffff, 0x0093, 0xfffe, 2 },
		{ "64 bit DS, qword a 0xfffffffffffffffc", CPU_MODE_64BIT, 8, 0, 0, 0x0093, 0xfffffffffffffffcULL, 8 },
	};
	int ko_prima = 0, ko_dopo = 0, gladiv = 0;

	printf("R9 prima/dopo (%s): vie_calculate_gla r5 contro ramo R9, oracolo SDM + regola (b)\n", argc > 1 ? argv[1] : "?");
	for (size_t i = 0; i < sizeof(cs) / sizeof(cs[0]); i++) {
		const struct caso *c = &cs[i];
		struct seg_desc d = { c->base, c->limit, c->acc };
		uint64_t gp = 0, gd = 0;
		const char *cl;
		int p = vie_prima(c->modo, VM_REG_GUEST_DS, &d, c->ea, c->len, c->asz, PROT_READ, &gp) != 0;
		int n = vie_dopo(c->modo, VM_REG_GUEST_DS, &d, c->ea, c->len, c->asz, PROT_READ, &gd) != 0;
		int a = atteso(c, &cl);

		ko_prima += p != a;
		ko_dopo += n != a;
		if (!p && !n && gp != gd)
			gladiv++;
		printf("  %-6s %-54s prima: %-6s dopo: %-6s atteso: %-6s %s\n", cl, c->nome, p ? "FUORI" : "lecito",
		    n ? "FUORI" : "lecito", a ? "FUORI" : "lecito", n != a ? "ERRATO" : (p != a ? "corretto da R9" : "="));
	}
	printf("%s: prima %d diversi dall'atteso, dopo %d; GLA diversi fra prima e dopo sugli accessi leciti: %d; KASSERT %d\n",
	    argc > 1 ? argv[1] : "?", ko_prima, ko_dopo, gladiv, kassert);
	return (ko_dopo != 0 || gladiv != 0 || kassert != 0);
}
