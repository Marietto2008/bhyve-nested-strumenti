/* stub.h -- Claude 31/10/2026, #169 R3: il minimo per compilare in userland le funzioni VERE di opnd_test.c.inc.
 * Ogni operazione sul VMCS e' registrata in un diario; FALLISCI = indice (1-based) della chiamata da far fallire. */
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8; typedef uint32_t u32; typedef uint64_t u64; typedef u64 pteval_t;
#define PAGE_SIZE 4096
#define GUEST_RIP 0x681e
#define OPND_VA 0x600000000000ULL
#define OPND_RIP_SENT 0xfeedface00001234ULL
#define OPND_NESSUNO 0xffffffffffffffffULL
struct vmcs { struct { u32 revision_id; } hdr; u8 resto[PAGE_SIZE - 4]; };
static struct { u32 revision; } basic_msr = { 0x12 };
static char diario[4096]; static int nop, falli, corrente_fittizia;	/* corrente: 0 nessuno, 1 cur, 2 tmp */
static int memset_tmp;
static struct vmcs vcur, vtmp;
static u64 virt_to_phys(void *p) { return p == &vcur ? 0x1000 : p == &vtmp ? 0x2000 : 0xdead; }
static int op(const char *nome) { strcat(diario, nome); strcat(diario, " "); return ++nop == falli; }
static int vmcs_clear(struct vmcs *v) { if (op("CLEAR")) return 1; if ((v == &vcur && corrente_fittizia == 1) || (v == &vtmp && corrente_fittizia == 2)) corrente_fittizia = 0; return 0; }
static int make_vmcs_current(struct vmcs *v) { if (op("LOAD")) return 1; corrente_fittizia = v == &vcur ? 1 : 2; return 0; }
static int vmcs_write(u64 f, u64 v) { (void)f; (void)v; return op("WRITE"); }
static u64 vmcs_read(u64 f) { (void)f; return op("READ") ? 0 : OPND_RIP_SENT; }
static u64 opnd_corrente(void) { if (op("PTRST")) return 0xbad; return corrente_fittizia == 0 ? OPND_NESSUNO : corrente_fittizia == 1 ? 0x1000 : 0x2000; }
static void invlpg(void *p) { (void)p; }
#define memset(d, c, n) (((void *)(d) == (void *)opnd_tmp ? (op("MEMSET"), memset_tmp++) : 0), memset((d), (c), (n)))
static int opnd_err;
static bool opnd_tmp_usato;
static struct vmcs *opnd_cur = &vcur, *opnd_tmp = &vtmp;
static u8 a0[PAGE_SIZE], a1[PAGE_SIZE], opnd_im0[PAGE_SIZE], opnd_im1[PAGE_SIZE];
static u8 *opnd_a0 = a0, *opnd_a1 = a1;
static pteval_t pte1, *opnd_pte1 = &pte1, opnd_pte1_ok = 7;
