/*
 * r9.c -- Claude 31/10/2026, parere #164 §6 (R9), passo 4: riproduzione PRIMA di ogni modifica. Chiama
 * vie_calculate_gla VERA (estratta da vmm_instruction_emul.c, identica nei due alberi) sui casi in cui l'offset di un
 * byte dell'accesso supera l'address size, e la confronta con un oracolo scritto dall'SDM (vol. 3A 6.3, gia' 5.3):
 * i byte sono agli offset EA .. EA + len - 1 NON troncati; expand-up: ultimo <= limite; expand-down: primo > limite e
 * ultimo <= 0xffff o 0xffffffff (bit B); con limite effettivo FFFFFFFFH il controllo e' implementation-specific (IMPL).
 * Accessi di UNA iterazione (1-8 byte): ogni iterazione REP ha il suo EA, qui non c'entra.
 * Uso: r9 <albero>
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

#include "vie.inc"

struct caso { const char *nome; enum vm_cpu_mode modo; int asz; uint64_t base; uint32_t limit, acc; uint64_t ea;
	int len; };

/* l'oracolo SDM: 0 accesso lecito, 1 fuori limite, 2 implementation-specific (limite effettivo FFFFFFFFH) */
static int
sdm(const struct caso *c)
{
	uint64_t primo = c->ea, ultimo = c->ea + c->len - 1, alto;
	uint32_t t = c->acc & 0x1f;

	if ((t & 0xc) == 0x4) {				/* dati expand-down */
		alto = (c->acc & 0x4000) ? 0xffffffffULL : 0xffffULL;
		if (primo <= c->limit)
			return (1);
		return (ultimo > alto ? (alto == 0xffffffffULL ? 2 : 1) : 0);
	}
	if (ultimo > c->limit)
		return (c->limit == 0xffffffffU ? 2 : 1);
	return (0);
}

int
main(int argc, char **argv)
{
	static const struct caso cs[] = {
		{ "16b expand-up lim 0xffff, word a 0xffff (MOVSW, SI=0xffff)", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xffff, 2 },
		{ "16b expand-up lim 0xffff, dword a 0xfffe", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xfffe, 4 },
		{ "16b expand-up lim 0xffff, dword a 0xfffd", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xfffd, 4 },
		{ "16b expand-up lim 0xffff, byte a 0xffff (controllo)", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xffff, 1 },
		{ "16b expand-up lim 0xfffff, word a 0xffff (67h, contiguo)", CPU_MODE_PROTECTED, 2, 0, 0xfffff, 0x4093, 0xffff, 2 },
		{ "16b expand-down B=1 lim 0x0fff, dword a 0xfffe", CPU_MODE_PROTECTED, 2, 0, 0x0fff, 0x4097, 0xfffe, 4 },
		{ "16b expand-down B=0 lim 0x0fff, dword a 0xfffe", CPU_MODE_PROTECTED, 2, 0, 0x0fff, 0x0097, 0xfffe, 4 },
		{ "16b SS expand-up lim 0xffff, word a 0xffff (PUSH)", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x0093, 0xffff, 2 },
		{ "32b (67h: indirizzi a 16) lim 0xffff, dword a 0xffff", CPU_MODE_PROTECTED, 2, 0, 0xffff, 0x4093, 0xffff, 4 },
		{ "32b piatto lim 0xffffffff base 0, dword a 0xfffffffe", CPU_MODE_PROTECTED, 4, 0, 0xffffffffU, 0xc093, 0xfffffffe, 4 },
		{ "32b lim 0xffffffff base 0x1000, dword a 0xfffffffe", CPU_MODE_PROTECTED, 4, 0x1000, 0xffffffffU, 0xc093, 0xfffffffe, 4 },
		{ "32b lim 0x7fffffff, dword a 0x7ffffffe (controllo)", CPU_MODE_PROTECTED, 4, 0, 0x7fffffff, 0xc093, 0x7ffffffe, 4 },
		{ "modo reale lim 0xffff, word a 0xffff", CPU_MODE_REAL, 2, 0, 0xffff, 0x0093, 0xffff, 2 },
		{ "modo reale lim 0xffff, dword a 0xfffe", CPU_MODE_REAL, 2, 0, 0xffff, 0x0093, 0xfffe, 4 },
	};
	static const char *esito[] = { "lecito", "FUORI LIMITE", "IMPL" };
	int diverge = 0, impl = 0;

	printf("R9, vie_calculate_gla vera (%s) contro l'SDM\n", argc > 1 ? argv[1] : "?");
	for (size_t i = 0; i < sizeof(cs) / sizeof(cs[0]); i++) {
		const struct caso *c = &cs[i];
		struct seg_desc d = { c->base, c->limit, c->acc };
		uint64_t gla = 0;
		int v = vie_calculate_gla(c->modo, VM_REG_GUEST_DS, &d, c->ea, c->len, c->asz, PROT_READ, &gla) != 0;
		int s = sdm(c);
		const char *cl = s == 2 ? "IMPL" : (v == s ? "uguale" : "DIVERGE");

		if (s == 2)
			impl++;
		else if (v != s)
			diverge++;
		printf("  %-8s %-58s vie: %-12s SDM: %s\n", cl, c->nome, v ? "FUORI LIMITE" : "lecito", esito[s]);
	}
	printf("%s: %d divergenze, %d implementation-specific, KASSERT %d\n", argc > 1 ? argv[1] : "?", diverge, impl,
	    kassert);
	return (0);
}
