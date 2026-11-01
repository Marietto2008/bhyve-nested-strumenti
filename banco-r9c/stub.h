/* stub.h -- Claude 31/10/2026, stadio 10: il minimo per compilare in userland le funzioni VERE di
 * vmm_instruction_emul.c (vie_calculate_gla e i suoi chiamanti get_gla ed emulate_stack_op). KASSERT CONTA invece di
 * fermare (nel kernel dell'host, con INVARIANTS, sarebbe un panic). Tutto lo stato del vCPU e' in g_*. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define _KERNEL 1
#undef __unused
#define __unused __attribute__((unused))
#define __diagused __attribute__((unused))
#define nitems(x) (sizeof(x) / sizeof((x)[0]))
static int kassert_falliti;
#define KASSERT(e, m) do { if (!(e)) { kassert_falliti++; } } while (0)
#define PROT_READ 1
#define PROT_WRITE 2
#define CR0_AM 0x40000
#define PSL_AC 0x40000
#define SEG_DESC_TYPE(access)		((access) & 0x001f)
#define SEG_DESC_PRESENT(access)	(((access) & 0x0080) ? 1 : 0)
#define SEG_DESC_DEF32(access)		(((access) & 0x4000) ? 1 : 0)
#define SEG_DESC_UNUSABLE(access)	(((access) & 0x10000) ? 1 : 0)
enum vm_cpu_mode { CPU_MODE_REAL, CPU_MODE_PROTECTED, CPU_MODE_COMPATIBILITY, CPU_MODE_64BIT };
enum vm_reg_name { VM_REG_GUEST_RAX, VM_REG_GUEST_RSI, VM_REG_GUEST_RDI, VM_REG_GUEST_RSP, VM_REG_GUEST_CR0,
	VM_REG_GUEST_RFLAGS, VM_REG_GUEST_ES, VM_REG_GUEST_CS, VM_REG_GUEST_SS, VM_REG_GUEST_DS, VM_REG_GUEST_FS,
	VM_REG_GUEST_GS, VM_REG_N };
struct seg_desc { uint64_t base; uint32_t limit; uint32_t access; };
struct vm_guest_paging { uint64_t cr3; int cpl; enum vm_cpu_mode cpu_mode; int paging_mode; };
struct vcpu { int x; };
enum { VIE_OP_TYPE_NONE, VIE_OP_TYPE_PUSH, VIE_OP_TYPE_POP };
struct vie_op { int op_type; };
struct vie { int opsize, opsize_override, reg; struct vie_op op; };
struct vm_copyinfo { int x; };
typedef int (*mem_region_read_t)(struct vcpu *, uint64_t, uint64_t *, int, void *);
typedef int (*mem_region_write_t)(struct vcpu *, uint64_t, uint64_t, int, void *);
/* stato del vCPU simulato ed eventi osservati */
static uint64_t g_reg[VM_REG_N];
static struct seg_desc g_seg[VM_REG_N];
static int g_getseg_ss, g_inj_ss, g_inj_gp, g_inj_ac, g_copy, g_copy_len;
static uint64_t g_copy_gla;
static int vie_read_register(struct vcpu *v, enum vm_reg_name r, uint64_t *x) { (void)v; *x = g_reg[r]; return (0); }
static int vm_get_seg_desc(struct vcpu *v, int r, struct seg_desc *d) { (void)v; if (r == VM_REG_GUEST_SS) g_getseg_ss++;
	*d = g_seg[r]; return (0); }
static void vm_inject_ss(struct vcpu *v, int e) { (void)v; (void)e; g_inj_ss++; }
static void vm_inject_gp(struct vcpu *v) { (void)v; g_inj_gp++; }
static void vm_inject_ac(struct vcpu *v, int e) { (void)v; (void)e; g_inj_ac++; }
static int vm_copy_setup(struct vcpu *v, struct vm_guest_paging *p, uint64_t gla, size_t len, int prot,
    struct vm_copyinfo *ci, int n, int *fault) { (void)v; (void)p; (void)prot; (void)ci; (void)n; g_copy++;
	g_copy_gla = gla; g_copy_len = (int)len; *fault = 0; return (0); }
static void vm_copyin(struct vm_copyinfo *ci, void *k, size_t l) { (void)ci; memset(k, 0, l); }
static void vm_copyout(const void *k, struct vm_copyinfo *ci, size_t l) { (void)k; (void)ci; (void)l; }
static void vm_copy_teardown(struct vm_copyinfo *ci, int n) { (void)ci; (void)n; }
static int vie_update_register(struct vcpu *v, enum vm_reg_name r, uint64_t x, int s) { (void)v; (void)s; g_reg[r] = x;
	return (0); }
uint64_t vie_size2mask(int size);
int vie_calculate_gla(enum vm_cpu_mode, enum vm_reg_name, struct seg_desc *, uint64_t, int, int, int, uint64_t *);
int vie_alignment_check(int, int, uint64_t, uint64_t, uint64_t);
int vie_canonical_check(enum vm_cpu_mode, uint64_t);
