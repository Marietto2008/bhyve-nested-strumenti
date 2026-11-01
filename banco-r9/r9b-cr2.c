/*
 * r9b-cr2.c -- Claude 31/10/2026, parere #165 §4 (R9b), riproduzione PRIMA di ogni modifica. Chiama vm_copy_setup
 * VERA del kernel (estratta da vmm.c, ramo R9: R9 non la tocca) per un accesso in modo PROTETTO a 32 bit che passa
 * 0xffffffff, con un segmento che lo lascia procedere anche dopo R9 (piatto: base 0, limite 0xffffffff). Registra gli
 * indirizzi lineari che chiede alla traduzione: il modello a 32 bit vuole 0xfffffffe e poi 0x0; il CR2 di un #PF
 * sulla seconda pagina e' l'indirizzo chiesto (vm_gla2gpa inietta il #PF con il gla ricevuto).
 */
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define PAGE_SIZE	4096
#define PAGE_MASK	(PAGE_SIZE - 1)
#define min(a, b)	((a) < (b) ? (a) : (b))
#define bzero(p, n)	memset((p), 0, (n))
#define bcopy(s, d, n)	memmove((d), (s), (n))
enum vm_cpu_mode { CPU_MODE_REAL, CPU_MODE_PROTECTED, CPU_MODE_COMPATIBILITY, CPU_MODE_64BIT };
struct vm_guest_paging { uint64_t cr3; int cpl; enum vm_cpu_mode cpu_mode; int paging_mode; };
struct vm_copyinfo { uint64_t gpa; size_t len; void *hva; void *cookie; };
struct vcpu { int x; };

static uint64_t chiesti[8], cr2;
static int nchiesti, pf_seconda;
static uint8_t mem[2 * PAGE_SIZE];
static int vm_gla2gpa(struct vcpu *v, struct vm_guest_paging *p, uint64_t gla, int prot, uint64_t *gpa, int *fault)
{
	(void)v; (void)p; (void)prot;
	chiesti[nchiesti++] = gla;
	*fault = 0;
	if (nchiesti == 2 && pf_seconda) {	/* vm_inject_pf(vcpu, pfcode, gla) del walk vero */
		cr2 = gla;
		*fault = 1;
		return (0);
	}
	*gpa = (nchiesti == 1 ? 0 : PAGE_SIZE) + (gla & PAGE_MASK);
	return (0);
}
static void *vm_gpa_hold(struct vcpu *v, uint64_t gpa, size_t len, int prot, void **cookie)
{
	(void)v; (void)len; (void)prot;
	*cookie = mem + gpa;
	return (mem + gpa);
}
static void vm_gpa_release(void *c) { (void)c; }

#include "vmcopy.inc"

int
main(void)
{
	struct vm_guest_paging pg = { 0, 0, CPU_MODE_PROTECTED, 1 };
	struct vm_copyinfo ci[2];
	struct vcpu v;
	int fault, e;

	for (pf_seconda = 0; pf_seconda < 2; pf_seconda++) {
		nchiesti = 0; cr2 = 0;
		e = vm_copy_setup(&v, &pg, 0xfffffffeULL, 4, 1, ci, 2, &fault);
		printf("dword a 0xfffffffe, modo protetto 32 bit%s: vm_copy_setup %d fault %d; gla chiesti:",
		    pf_seconda ? ", #PF sulla seconda pagina" : "", e, fault);
		for (int i = 0; i < nchiesti; i++)
			printf(" %#lx", (unsigned long)chiesti[i]);
		if (pf_seconda)
			printf("; CR2 %#lx (modello a 32 bit: 0)", (unsigned long)cr2);
		printf("  -> %s\n", nchiesti == 2 && chiesti[1] == 0 ? "come il modello" : "DIVERGE: seconda pagina oltre 4 GB");
		if (!fault && e == 0)
			vm_copy_teardown(ci, 2);
	}
	return (0);
}
