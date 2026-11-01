/*
 * stub.h -- Claude 30/10/2026, parere #155 (P3). Ambiente minimo per compilare IN USERLAND le funzioni VERE del walk
 * (_vm_gla2gpa e aiutanti) estratte da sys/amd64/vmm/vmm_instruction_emul.c dei due cloni (base senza nesting,
 * nested). L'"avversario" e' negli stub: un'altra CPU che scrive la voce subito prima del cmpset (vince la corsa),
 * oppure (solo nested) l'L1 che cambia EPT12 fra la lettura e la scrittura degli A/D (EAGAIN).
 */
#include <errno.h>
#include <pthread.h>
#include <setjmp.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EJUSTRETURN	(-2)
typedef uint64_t vm_paddr_t;
typedef unsigned int u_int;
typedef unsigned long u_long;
struct vcpu { int id; };
enum vm_cpu_mode { CPU_MODE_REAL, CPU_MODE_PROTECTED, CPU_MODE_COMPATIBILITY, CPU_MODE_64BIT };
enum vm_paging_mode { PAGING_MODE_FLAT, PAGING_MODE_32, PAGING_MODE_PAE, PAGING_MODE_64, PAGING_MODE_64_LA57 };
struct vm_guest_paging { uint64_t cr3; int cpl; enum vm_cpu_mode cpu_mode; enum vm_paging_mode paging_mode; };

#define PAGE_SHIFT	12
#define PAGE_SIZE	4096
#define PAGE_MASK	(PAGE_SIZE - 1)
#define GB		(1UL << 30)
#define PG_V		0x001
#define PG_RW		0x002
#define PG_U		0x004
#define PG_A		0x020
#define PG_M		0x040
#define PG_PS		0x080
#define PG_NX		(1UL << 63)
#define PGEX_P		0x01
#define PGEX_W		0x02
#define PGEX_U		0x04
#define PGEX_RSV	0x08
#define PGEX_I		0x10
#define VM_PROT_READ	0x1
#define VM_PROT_WRITE	0x2
#define VM_PROT_EXECUTE	0x4
#define VM_PROT_RW	(VM_PROT_READ | VM_PROT_WRITE)
#define VM_NGPA_RECORD	0x01
#define VM_NGPA_FINAL	0x02
#define VM_NGPA_LA_US	0x04
#define VM_NGPA_LA_RW	0x08
#define VM_NGPA_LA_XD	0x10
#define KASSERT(c, m)	do { if (!(c)) { printf("KASSERT FALLITA: %s\n", #c); kassert_fallite++; } } while (0)

static int kassert_fallite;
static u_long gla2gpa_pend_restart;		/* contatore diagnostico del nested (#127 A) */

/* --- l'avversario */
static long avv_cas;		/* cmpset da far perdere: >0 quanti, -1 sempre, 0 nessuno */
static long avv_ept;		/* EAGAIN da vm_nested_ptp_write: >0 quanti, -1 sempre */
static long cas_tentati, cas_sabotati, ept_eagain;
static void avversario_cas(volatile void *p, int w32)
{
	cas_tentati++;
	if (avv_cas == 0)
		return;
	if (avv_cas > 0)
		avv_cas--;
	cas_sabotati++;
	/* un'altra CPU scrive la voce (bit 9, ignorato dal walk) fra la lettura e il cmpset: il valore atteso non c'e' piu' */
	if (w32)
		__sync_fetch_and_xor((volatile uint32_t *)p, 0x200u);
	else
		__sync_fetch_and_xor((volatile uint64_t *)p, 0x200ul);
}
#define atomic_cmpset_64(p, o, n)	(avversario_cas((p), 0), __sync_bool_compare_and_swap((p), (o), (n)))
#define atomic_cmpset_32(p, o, n)	(avversario_cas((p), 1), __sync_bool_compare_and_swap((p), (o), (n)))
#define atomic_add_long(p, v)		(*(p) += (v))

/* --- il "punto di uscita": ogni ripartenza oltre la prima chiama maybe_yield; il banco conta e, oltre il limite,
 * esce con longjmp (la funzione vera non avrebbe mai smesso da sola) */
static long ripartenze, limite_ripartenze = 100000;
static jmp_buf salto;
static void maybe_yield(void)
{
	if (++ripartenze >= limite_ripartenze)
		longjmp(salto, 1);
}

/* --- memoria del guest e servizi del VMM */
#define MEMPAG	16
static uint8_t mem[MEMPAG * PAGE_SIZE] __attribute__((aligned(4096)));
static long iniezioni_pf, iniezioni_gp, ripartenze_istruzione;
static void *vm_gpa_hold(struct vcpu *v, vm_paddr_t gpa, size_t len, int prot, void **cookie)
{
	(void)v; (void)prot;
	if (gpa + len > sizeof(mem))
		return (NULL);
	*cookie = (void *)1;
	return (mem + gpa);
}
static void vm_gpa_release(void *cookie) { (void)cookie; }
static long eventi_nested;	/* violazioni EPT12 registrate per l'L1 (H2): una causa legittima di fault=1 */
static int nega_finale;		/* #156: EPT12 nega l'accesso finale (con VM_NGPA_RECORD -> evento + EJUSTRETURN) */
static int vm_nested_gpa(struct vcpu *v, uint64_t gpa, int prot, uint64_t gla, int flags, uint64_t *l1gpa)
{
	(void)v; (void)prot; (void)gla;
	*l1gpa = gpa;			/* EPT12 identita' */
	if (nega_finale && (flags & VM_NGPA_FINAL)) {
		if ((flags & VM_NGPA_RECORD) == 0)
			return (EFAULT);	/* nofault: nessuna registrazione */
		eventi_nested++;
		return (EJUSTRETURN);
	}
	return (0);
}
static int vm_nested_ptp_write(struct vcpu *v, uint64_t ptegpa, uint64_t l1held, uint64_t gla, bool *denied)
{
	(void)v; (void)ptegpa; (void)l1held; (void)gla;
	*denied = false;
	if (avv_ept != 0) {
		if (avv_ept > 0)
			avv_ept--;
		ept_eagain++;
		return (EAGAIN);	/* l'L1 ha cambiato/rimappato EPT12 fra la lettura e la scrittura */
	}
	return (0);
}
static void vm_inject_pf(struct vcpu *v, int code, uint64_t gla) { (void)v; (void)code; (void)gla; iniezioni_pf++; }
static void vm_inject_gp(struct vcpu *v) { (void)v; iniezioni_gp++; }
static int vm_restart_instruction(struct vcpu *v) { (void)v; ripartenze_istruzione++; return (0); }
