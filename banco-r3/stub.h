/*
 * stub.h -- Claude 30/10/2026, parere #158 B4d (R3). Ambiente minimo per compilare IN USERLAND le funzioni VERE
 * del clone nested: da vmx_nested.c il calcolo dell'operando VMX (nested_operand_gpa_at) e tre gestori che lo
 * usano (VMPTRST, VMCLEAR, INVVPID); da vmm.c vm_set_register e vm_restart_instruction (chi muove nextrip).
 * Lo stub decide l'esito della traduzione (OK, #PF iniettato, EFAULT dell'host) e di vmx_getdesc.
 * Le iniezioni seguono vm_inject_exception (vmm.c:1816: restart_instruction=1 -> vm_restart_instruction).
 */
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

typedef unsigned long u_long;
#define __diagused
#define __predict_false(x)	(x)
#define nitems(a)		(sizeof(a) / sizeof((a)[0]))
#define KASSERT(c, m)		do { if (!(c)) { printf("KASSERT FALLITA: %s\n", #c); kassert_fallite++; } } while (0)
#define VMM_CTR1(v, f, a)		do { } while (0)
#define VMM_CTR2(v, f, a, b)	do { } while (0)
#define panic(...)		do { printf("PANIC: " __VA_ARGS__); printf("\n"); exit(3); } while (0)
static int kassert_fallite;

#define PAGE_SIZE	4096
#define PAGE_MASK	(PAGE_SIZE - 1)
#define VM_PROT_READ	1
#define VM_PROT_WRITE	2
#define PSL_C	0x001
#define PSL_PF	0x004
#define PSL_AF	0x010
#define PSL_Z	0x040
#define PSL_N	0x080
#define PSL_V	0x800

enum vm_reg_name {
	VM_REG_GUEST_ES, VM_REG_GUEST_CS, VM_REG_GUEST_SS, VM_REG_GUEST_DS, VM_REG_GUEST_FS, VM_REG_GUEST_GS,
	VM_REG_GUEST_RIP, VM_REG_GUEST_RFLAGS, VM_REG_GUEST_CR2, VM_REG_LAST
};
enum vm_cpu_mode { CPU_MODE_REAL, CPU_MODE_PROTECTED, CPU_MODE_COMPATIBILITY, CPU_MODE_64BIT };
struct vm_guest_paging { uint64_t cr3; int cpl; enum vm_cpu_mode cpu_mode; int paging_mode; };
struct seg_desc { uint64_t base; uint32_t limit; uint32_t access; };
enum vcpu_state { VCPU_IDLE, VCPU_FROZEN, VCPU_RUNNING, VCPU_SLEEPING };

struct vm_exit { uint64_t rip; int inst_length; };
struct vcpu {
	uint64_t nextrip;
	struct vm_exit exitinfo;
	void *cookie;
	uint64_t regs[VM_REG_LAST];
	enum vcpu_state stato;
};

#define VMX_NESTED_MAX_VMCS12	4
#define VMCS12_GPA_NONE		(~0ULL)
#define VMXR_SUCCEED		0
#define VMXERR_VMCLEAR_INVALID_ADDRESS		2
#define VMXERR_VMCLEAR_VMXON_POINTER		3
#define VMXERR_INVALID_OPERAND_TO_INVEPT_INVVPID 28
#define VMCS12_OP_SAVE_VMCLEAR	2
#define INVVPID_TYPE_SINGLE_CONTEXT	1
struct invvpid_desc { uint16_t vpid; uint16_t _res1; uint32_t _res2; uint64_t linear_addr; };
struct vmcs12_cache { uint64_t vmcs12_gpa; int launched; int nfields; };
struct vmx_nested {
	int vmxon;
	uint64_t exit_qual, exit_insn_info, exit_insn_length;
	struct vm_guest_paging exit_paging;
	uint64_t vmxon_ptr, current_vmcs12;
	struct vmcs12_cache cache[VMX_NESTED_MAX_VMCS12];
	uint64_t vmx_msr[0x20];
	uint16_t vpid2;
	int vpid02_off, vpid_track;
};
struct vmx_vcpu { struct vcpu *vcpu; struct vmx_nested *nested; uint64_t gpr[16]; };

/* --- scena controllata dal banco */
enum { G_OK, G_PF, G_EFAULT };
static struct {
	int gla2gpa[2];		/* esito per chiamata (INVVPID ne fa due) */
	int nchiamate;
	int getdesc_err;
	long eccezioni, risultati, vmfail, invvpid_hw, salvataggi;
} sc;
static u_long vpid02_invvpid_l1insn;
static int cpu_maxphyaddr = 39;
#define atomic_add_long(p, v)	(*(p) += (v))
#define vmm_stat_incr(v, s, n)	do { } while (0)
#define bzero(p, n)		memset((p), 0, (n))

/* --- memoria del guest */
static uint8_t mem[16 * PAGE_SIZE] __attribute__((aligned(4096)));
#include <setjmp.h>
static jmp_buf salto_panic;
static int panici;
static char panic_msg[128];
static void *vm_gpa_hold(struct vcpu *v, uint64_t gpa, size_t len, int prot, void **cookie)
{
	(void)v; (void)prot;
	/* lo stesso controllo, incondizionato, di _vm_gpa_hold (sys/dev/vmm/vmm_mem.c:489-491) */
	if (len > PAGE_SIZE - (gpa & PAGE_MASK)) {
		panici++;
		snprintf(panic_msg, sizeof(panic_msg), "vm_gpa_hold: invalid gpa/len: 0x%016lx/%lu", (u_long)gpa, (u_long)len);
		longjmp(salto_panic, 1);
	}
	if (gpa + len > sizeof(mem))
		return (NULL);
	*cookie = (void *)1;
	return (mem + gpa);
}
static void vm_gpa_release(void *cookie) { (void)cookie; }

/* --- registri: vmmops_setreg/vm_get_register sullo stato del vcpu */
static int vmmops_setreg(void *cookie, int reg, uint64_t val)
{
	((struct vmx_vcpu *)cookie)->vcpu->regs[reg] = val;
	return (0);
}
static int vm_get_register(struct vcpu *v, int reg, uint64_t *val) { *val = v->regs[reg]; return (0); }
static enum vcpu_state vcpu_get_state(struct vcpu *v, int *hc) { (void)hc; return (v->stato); }
static uint64_t vmx_get_guest_reg(struct vmx_vcpu *x, int ident) { return (x->gpr[ident]); }
static enum vm_reg_name vm_segment_name(int s) { return ((enum vm_reg_name)s); }
static int vmx_getdesc(void *x, int reg, struct seg_desc *d)
{
	(void)x; (void)reg;
	memset(d, 0, sizeof(*d));
	return (sc.getdesc_err);
}
static int vie_calculate_gla(enum vm_cpu_mode m, enum vm_reg_name seg, struct seg_desc *d, uint64_t off, int len,
    int asz, int prot, uint64_t *gla)
{
	(void)m; (void)seg; (void)d; (void)len; (void)asz; (void)prot;
	*gla = off;
	return (0);
}

/* prototipi di quanto viene estratto da vmm.c (l'ordine nel .inc e' quello dell'estrazione) */
int vm_set_register(struct vcpu *vcpu, int reg, uint64_t val);
int vm_restart_instruction(struct vcpu *vcpu);
static int nested_operand_gpa_at(struct vmx_vcpu *vcpu, int prot, uint64_t add, uint64_t *gpa);

/* --- iniezioni: come vm_inject_exception con restart_instruction=1 (vmm.c:1816) */
static void inietta(struct vcpu *v) { sc.eccezioni++; vm_restart_instruction(v); }
static void vm_inject_ud(struct vcpu *v) { inietta(v); }
static void vm_inject_gp(struct vcpu *v) { inietta(v); }
static void vm_inject_ss(struct vcpu *v, int e) { (void)e; inietta(v); }
static void vm_inject_pf(struct vcpu *v, int e, uint64_t cr2) { (void)e; v->regs[VM_REG_GUEST_CR2] = cr2; inietta(v); }

/* --- la traduzione: contratto di vm_gla2gpa (0/0 tradotto, 0/1 eccezione iniettata, EFAULT errore dell'host) */
static int vm_gla2gpa(struct vcpu *v, struct vm_guest_paging *p, uint64_t gla, int prot, uint64_t *gpa, int *fault)
{
	int e = sc.gla2gpa[sc.nchiamate < 2 ? sc.nchiamate : 1];

	(void)p; (void)prot;
	sc.nchiamate++;
	*fault = 0;
	switch (e) {
	case G_OK:
		*gpa = gla;
		return (0);
	case G_PF:
		vm_inject_pf(v, 0, gla);
		*fault = 1;
		return (0);
	default:
		return (EFAULT);	/* es. una tabella delle pagine dell'L1 su un GPA senza memoria (ptp_hold NULL) */
	}
}

/* --- servizi dei gestori, fuori dal perimetro di R3 */
static void nested_vmx_result(struct vmx_vcpu *x, int errnum)	/* semplificata: VMsucceed / VMfailValid */
{
	uint64_t r;

	sc.risultati++;
	vm_get_register(x->vcpu, VM_REG_GUEST_RFLAGS, &r);
	r &= ~(PSL_C | PSL_PF | PSL_AF | PSL_Z | PSL_N | PSL_V);
	if (errnum != VMXR_SUCCEED)
		r |= PSL_Z;
	vm_set_register(x->vcpu, VM_REG_GUEST_RFLAGS, r);
}
static void shvmcs_set_current(struct vmx_nested *n, void *c) { (void)n; (void)c; }
static int vmcs12_mem_save(struct vmx_vcpu *x, struct vmcs12_cache *c, int l, int op) { (void)x; (void)c; (void)l; (void)op; sc.salvataggi++; return (0); }
static int vmcs12_mem_clear(struct vmx_vcpu *x, uint64_t g) { (void)x; (void)g; sc.salvataggi++; return (0); }
static void nested_bitmaps_unmap(struct vmcs12_cache *c) { (void)c; }
static void invvpid(uint64_t t, struct invvpid_desc d) { (void)t; (void)d; sc.invvpid_hw++; }
static void nested_vpid02_request(struct vmx_nested *n) { (void)n; }
