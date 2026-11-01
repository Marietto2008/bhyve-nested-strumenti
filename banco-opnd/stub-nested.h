/*
 * stub-nested.h -- Claude 30/10/2026, parere #160. Il lato nested del banco-opnd: lo stato VMX dell'L1, la MMU
 * dell'L1 (due pagine P0/P1 su GPA NON contigui, esito per pagina), la memoria del guest con hold/release contati e
 * il controllo incondizionato di _vm_gpa_hold (sys/dev/vmm/vmm_mem.c:489-491).
 * #161: vmx_nested_exit e' quella VERA (estratta); qui solo il suo prefisso (statistiche, memgen, emu_viol,
 * restart_only, ept_pending, shvmcs_pull), contato, e i gestori fuori perimetro (VMXOFF, VMLAUNCH/VMRESUME).
 * #162: fuori dal modo 64 bit la MMU e' STRETTA: un indirizzo lineare oltre 0xffffffff non esiste (il codice deve
 * averlo avvolto); si conta (OLTRE_4G) e si risponde EFAULT. shvmcs_pull e' quella VERA (estratta e rinominata
 * shvmcs_pull_vera; qui un passante che conta), su uno shadow VMCS simulato.
 */
#define nitems(a)		(sizeof(a) / sizeof((a)[0]))
#define min(a, b)		((a) < (b) ? (a) : (b))
#define bzero(p, n)		memset((p), 0, (n))
#define bcopy(s, d, n)		memmove((d), (s), (n))
#define PAGE_MASK		(PAGE_SIZE - 1)
#define VM_PROT_READ		1
#define VM_PROT_WRITE		2
#define PROT_READ		VM_PROT_READ
#define PROT_WRITE		VM_PROT_WRITE
#define ENOTRECOVERABLE_BANCO	ENOTRECOVERABLE
#define PSL_C	0x001
#define PSL_PF	0x004
#define PSL_AF	0x010
#define PSL_Z	0x040
#define PSL_N	0x080
#define PSL_V	0x800
#define CR4_VMXE	0x2000
#define IA32_FEATURE_CONTROL_LOCK	0x1
#define IA32_FEATURE_CONTROL_VMX_EN	0x4
#define VMCS_CR0_MASK		0x6000
#define VMCS_CR0_SHADOW		0x6004
#define VMCS_CR4_MASK		0x6002
#define VMCS_CR4_SHADOW		0x6006
#define VMX_NESTED_MAX_VMCS12	4
#define VMCS12_GPA_NONE		(~0ULL)
#define VMXR_SUCCEED		0
#define VMXERR_VMCLEAR_INVALID_ADDRESS		2
#define VMXERR_VMCLEAR_VMXON_POINTER		3
#define VMXERR_VMPTRLD_INVALID_ADDRESS		9
#define VMXERR_VMPTRLD_VMXON_POINTER		10
#define VMXERR_VMPTRLD_INCORRECT_REVISION	11
#define VMXERR_UNSUPPORTED_VMCS_COMPONENT	12
#define VMXERR_VMXON_IN_VMX_ROOT		15
#define VMXERR_INVALID_OPERAND_TO_INVEPT_INVVPID 28
#define VMCS12_OP_SAVE_EVICT	1
#define VMCS12_OP_SAVE_VMCLEAR	2
#define INVVPID_TYPE_SINGLE_CONTEXT	1
#define NESTED_FIELD_HIGH(f)	(((f) & 1) != 0)
enum { VMX_NESTED_VMFAIL, VMX_NESTED_VMFAIL_INVALID, VMX_NESTED_INVEPT_SINGLE, VMX_NESTED_INVEPT_ALL,
	VMX_NESTED_VEPT_WIPED, VMX_NESTED_SLOWPATH };
enum { EXIT_REASON_VMCLEAR = 19, EXIT_REASON_VMLAUNCH = 20, EXIT_REASON_VMPTRLD = 21, EXIT_REASON_VMPTRST = 22,
	EXIT_REASON_VMREAD = 23, EXIT_REASON_VMRESUME = 24, EXIT_REASON_VMWRITE = 25, EXIT_REASON_VMXOFF = 26,
	EXIT_REASON_VMXON = 27, EXIT_REASON_INVEPT = 50, EXIT_REASON_INVVPID = 53 };
#define SDT_PROBE1(p, m, f, n, a0)	do { } while (0)
/* sbintime_t e sbttons vengono da <sys/time.h> (userland); sbinuptime e' solo del kernel */
static inline sbintime_t sbinuptime(void) { return (0); }

struct seg_desc { uint64_t base; uint32_t limit; uint32_t access; };
struct vm_copyinfo { uint64_t gpa; size_t len; void *hva; void *cookie; };
struct invvpid_desc { uint16_t vpid; uint16_t _res1; uint32_t _res2; uint64_t linear_addr; };
struct vmcs12_cache { uint64_t vmcs12_gpa; int launched, nfields; bool control_dirty, host_dirty; uint64_t campo;
	bool sh_rw_owned; uint64_t shf[16]; };
struct vmx_nested {
	bool vmxon, last_vpid12_ok;
	uint64_t exit_qual, exit_insn_info, exit_insn_length;
	struct vm_guest_paging exit_paging;
	uint64_t vmxon_ptr, current_vmcs12, feature_control;
	struct vmcs12_cache cache[VMX_NESTED_MAX_VMCS12];
	int evict_next;
	uint64_t vmx_msr[0x20];
	uint16_t vpid2;
	int vpid02_off, vpid_track;
	bool vept_keep, vept_memgen_pending, emu_viol, in_l2, restart_only, ept_pending;	/* prefisso di vmx_nested_exit */
	bool sh_on, sh_fault, sh_live;			/* shadow VMCS (#162: shvmcs_pull vera) */
	struct vmcs12_cache *sh_cache;
	void *sh_vmcs;
	uint32_t sh_push;
};
struct vmx { void *vm; };
struct vmx_vcpu { struct vcpu *vcpu; struct vmx_nested *nested; int vcpuid; uint64_t gpr[16]; struct vmx *vmx; };

static u_long nested_operand_fatal, nested_invept_ns_sum, nested_invept_ns_max, vpid02_invvpid_l1insn,
    nested_ept12_viol_emul_stale, nested_sh_pull_changed, nested_sh_verify, nested_sh_pull, nested_sh_pull_tsc,
    nested_sh_faults, nested_sh_first_fault;
static int nested_shadow_verify, nested_shadow_inject;
static uint32_t shv_rw_mask;
#define SHV_RW		0x1
#define SHF_VERIFY	1
#define SHF_INJECTED	2
#define SHF_VMX		4
#define SHF_GUARD	8
#define VM_SUSPEND_POWEROFF	2
/* le codifiche dei campi dello shadow (valori SDM; la tabella shv_fields e' estratta dal sorgente) */
#define VMCS_GUEST_INTERRUPTIBILITY	0x4824
#define VMCS_GUEST_RFLAGS		0x6820
#define VMCS_GUEST_RIP			0x681e
#define VMCS_GUEST_CS_ACCESS_RIGHTS	0x4816
#define VMCS_GUEST_SS_ACCESS_RIGHTS	0x4818
#define VMCS_EXIT_REASON		0x4402
#define VMCS_EXIT_QUALIFICATION		0x6400
#define VMCS_EXIT_INSTRUCTION_LENGTH	0x440c
#define VMCS_EXIT_INTR_INFO		0x4404
#define VMCS_EXIT_INTR_ERRCODE		0x4406
#define VMCS_IDT_VECTORING_INFO		0x4408
#define VMCS_IDT_VECTORING_ERROR	0x440a
#define VMCS_EXIT_INSTRUCTION_INFO	0x440e
#define VMCS_GUEST_LINEAR_ADDRESS	0x640a
#define VMCS_GUEST_PHYSICAL_ADDRESS	0x2400
static const uint32_t banco_shv_enc[] = { 0x4824, 0x6820, 0x681e, 0x4816, 0x4818, 0x4402, 0x6400, 0x440c, 0x4404,
	0x4406, 0x4408, 0x440a, 0x440e, 0x640a, 0x2400 };
static int banco_shv_idx(uint32_t e) { for (int i = 0; i < 15; i++) if (banco_shv_enc[i] == e) return (i); return (-1); }
static inline int atomic_cmpset_int(volatile int *p, int o, int nv) { if (*p != o) return (0); *p = nv; return (1); }
static inline int atomic_cmpset_long(volatile u_long *p, u_long o, u_long nv) { if (*p != o) return (0); *p = nv; return (1); }
static int cpu_maxphyaddr = 39;

/* --- la scena dell'operando, pilotata dal banco */
enum { PG_OK, PG_PF, PG_EFAULT, PG_NOBACK, PG_RO };	/* esito della traduzione di una pagina dell'L1 */
#define MEMSZ		0x20000
#define GPA_P0		0x5000		/* P0 -> 0x5000, P1 -> 0x9000: NON contigui */
#define GPA_P1		0x9000
#define GPA_NOBACK	0x40000		/* oltre la memoria: vm_gpa_hold -> NULL */
static uint8_t mem[MEMSZ] __attribute__((aligned(4096)));
static struct {
	int motivo;			/* EXIT_REASON_* dell'istruzione VMX */
	uint64_t gla;			/* indirizzo lineare dell'operando */
	uint64_t pag[2];		/* pagine dell'L1: P0 = trunc(gla), P1 = P0 + 4K */
	int esito[2];			/* PG_* per pagina */
	int getdesc_err;
	uint32_t limite;		/* limite di segmento (0 = nessuno) */
	int seg;			/* registro di segmento dell'operando (3 = DS, 2 = SS) */
	int holds, hold_max_len_fuori;	/* hold aperti; hold oltre la pagina (= panic) */
	int tradotte[2];		/* traduzioni per pagina */
	int eccezioni, vettore;		/* eccezioni iniettate e l'ultima */
	int risultati, vmfail;		/* nested_vmx_result chiamate; VMfail dati */
	int invvpid_hw, invept_chiamate;
	uint64_t invept_eptp;
	int panici;
	char panic_msg[128];
	jmp_buf salto;			/* panic dell'host o giro illimitato */
	int giro_illimitato;
	int ecc_ingresso;		/* eccezioni gia' viste all'ultimo ingresso */
	int mask32;			/* fuori dal modo 64 bit: indirizzi lineari a 32 bit */
	int flush, shvmcs, shvmcs_err, altri_gestori, prefisso_altro;	/* prefisso di vmx_nested_exit */
	int shvmcs_dopo_gestore;	/* shvmcs_pull chiamata DOPO l'ingresso nel gestore (ordine sbagliato) */
	int nel_gestore;
	uint64_t base;			/* base del segmento dell'operando (fuori dal modo 64 bit) */
	int oltre4g;			/* traduzioni chieste oltre 0xffffffff fuori dal modo 64 bit */
	uint64_t cr2;			/* CR2 dell'ultimo #PF */
	uint64_t shadow[16];		/* lo shadow VMCS simulato */
	int vmread_err, sospesa;
	int sosp_dopo;			/* VM gia' sospesa da un errore precedente: dal secondo ingresso */
} op;
static struct vmx_vcpu xv;
static struct vmx_nested nn;

int vm_set_register(struct vcpu *vcpu, int reg, uint64_t val);

/* --- la memoria del guest */
static void *vm_gpa_hold(struct vcpu *v, uint64_t gpa, size_t len, int prot, void **cookie)
{
	(void)v; (void)prot;
	/* lo stesso controllo, incondizionato, di _vm_gpa_hold (sys/dev/vmm/vmm_mem.c:489-491) */
	if (len > PAGE_SIZE - (gpa & PAGE_MASK)) {
		op.panici++;
		snprintf(op.panic_msg, sizeof(op.panic_msg), "vm_gpa_hold: invalid gpa/len: 0x%016lx/%lu",
		    (u_long)gpa, (u_long)len);
		longjmp(op.salto, 1);
	}
	if (gpa + len > MEMSZ)
		return (NULL);
	op.holds++;
	*cookie = (void *)(mem + gpa);
	return (mem + gpa);
}
static void vm_gpa_release(void *cookie) { (void)cookie; op.holds--; }

/* --- iniezioni: come vm_inject_exception con restart_instruction=1 (vmm.c:1816) */
static void inietta(struct vcpu *v, int vec) { op.eccezioni++; op.vettore = vec; vm_restart_instruction(v); }
static void vm_inject_ud(struct vcpu *v) { inietta(v, 6); }
static void vm_inject_gp(struct vcpu *v) { inietta(v, 13); }
static void vm_inject_ss(struct vcpu *v, int e) { (void)e; inietta(v, 12); }
static void vm_inject_pf(struct vcpu *v, int e, uint64_t cr2) { (void)e; v->regs[VM_REG_GUEST_CR2] = cr2; op.cr2 = cr2; inietta(v, 14); }

/* --- la MMU dell'L1: contratto di vm_gla2gpa (0/0 tradotto, 0/1 eccezione iniettata, EFAULT errore dell'host) */
static int vm_gla2gpa(struct vcpu *v, struct vm_guest_paging *p, uint64_t gla, int prot, uint64_t *gpa, int *fault)
{
	uint64_t pg = gla & ~(uint64_t)PAGE_MASK;
	int i = pg == op.pag[0] ? 0 : pg == op.pag[1] ? 1 : -1;

	*fault = 0;
	if (p->cpu_mode != CPU_MODE_64BIT && gla > 0xffffffffULL) {	/* nessun indirizzo lineare oltre 4 GB */
		op.oltre4g++;
		return (EFAULT);
	}
	if (i < 0) {
		printf("  BANCO: traduzione di una pagina fuori scena %#lx\n", (u_long)gla);
		return (EFAULT);
	}
	op.tradotte[i]++;
	switch (op.esito[i]) {
	case PG_RO:
		if ((prot & VM_PROT_WRITE) == 0)
			goto ok;
		/* FALLTHROUGH: scrittura su pagina di sola lettura */
	case PG_PF:
		vm_inject_pf(v, 0, gla);
		*fault = 1;
		return (0);
	case PG_EFAULT:
		return (EFAULT);	/* es. una tabella dell'L1 su un GPA senza memoria (ptp_hold NULL) */
	case PG_NOBACK:
		*gpa = GPA_NOBACK + (gla & PAGE_MASK);
		return (0);
	}
ok:
	*gpa = (i == 0 ? GPA_P0 : GPA_P1) + (gla & PAGE_MASK);
	return (0);
}
/* scrittura/lettura dell'L1 per indirizzo lineare, attraverso la stessa mappa (solo il banco) */
static uint8_t *l1byte(uint64_t gla)
{
	uint64_t pg;

	if (op.mask32)
		gla &= 0xffffffffULL;
	pg = gla & ~(uint64_t)PAGE_MASK;

	return (mem + (pg == op.pag[0] ? GPA_P0 : GPA_P1) + (gla & PAGE_MASK));
}

/* --- segmenti */
static enum vm_reg_name vm_segment_name(int s);
/*
 * #163: vie_calculate_gla, vie_size2mask e size2mask[] sono quelle VERE (estratte da vmm_instruction_emul.c); qui
 * solo le macro dei descrittori (sys/amd64/include/vmm.h:518-523) e il descrittore della scena.
 */
#define SEG_DESC_TYPE(access)		((access) & 0x001f)
#define SEG_DESC_DPL(access)		(((access) >> 5) & 0x3)
#define SEG_DESC_PRESENT(access)	(((access) & 0x0080) ? 1 : 0)
#define SEG_DESC_DEF32(access)		(((access) & 0x4000) ? 1 : 0)
#define SEG_DESC_GRANULARITY(access)	(((access) & 0x8000) ? 1 : 0)
#define SEG_DESC_UNUSABLE(access)	(((access) & 0x10000) ? 1 : 0)
#define CTASSERT(x)			_Static_assert(x, "CTASSERT")
static struct seg_desc desc_scena;
static int vmx_getdesc(void *x, int reg, struct seg_desc *d)
{
	(void)x; (void)reg;
	*d = desc_scena;
	return (op.getdesc_err);
}

/* --- registri generali e stato VMX */
static uint64_t vmx_get_guest_reg(struct vmx_vcpu *x, int ident) { return (x->gpr[ident]); }
static void vmx_set_guest_reg(struct vmx_vcpu *x, int ident, uint64_t v) { x->gpr[ident] = v; }
static struct vm_exit *vm_exitinfo(struct vcpu *v) { return (&v->exitinfo); }
static struct vmcs12_cache *nested_current_cache(struct vmx_nested *n)
{
	for (int i = 0; i < VMX_NESTED_MAX_VMCS12; i++)
		if (n->current_vmcs12 != VMCS12_GPA_NONE && n->cache[i].vmcs12_gpa == n->current_vmcs12)
			return (&n->cache[i]);
	return (NULL);
}
/* semplificata (fuori perimetro): VMsucceed spegne i flag aritmetici, VMfailValid accende ZF, VMfailInvalid CF */
static void nested_vmx_result(struct vmx_vcpu *x, int errnum)
{
	uint64_t r;

	op.risultati++;
	vm_get_register(x->vcpu, VM_REG_GUEST_RFLAGS, &r);
	r &= ~(uint64_t)(PSL_C | PSL_PF | PSL_AF | PSL_Z | PSL_N | PSL_V);
	if (errnum != VMXR_SUCCEED) {
		op.vmfail++;
		r |= nested_current_cache(x->nested) != NULL ? PSL_Z : PSL_C;
	}
	vm_set_register(x->vcpu, VM_REG_GUEST_RFLAGS, r);
}
static uint64_t nested_guest_cr(struct vmx_vcpu *x, int reg, uint32_t m, uint32_t s)
{
	(void)x; (void)m; (void)s;
	return (reg == VM_REG_GUEST_CR4 ? CR4_VMXE : 0x80000021);
}
static void shvmcs_set_current(struct vmx_nested *n, struct vmcs12_cache *c) { (void)n; (void)c; }
static void shvmcs_mark(struct vmx_nested *n, struct vmcs12_cache *c, uint32_t f) { (void)n; (void)c; (void)f; }
static int vmcs12_mem_save(struct vmx_vcpu *x, struct vmcs12_cache *c, int l, int o) { (void)x; (void)c; (void)l; (void)o; return (0); }
static int vmcs12_mem_clear(struct vmx_vcpu *x, uint64_t g) { (void)x; (void)g; return (0); }
static int vmcs12_mem_load(struct vmx_vcpu *x, struct vmcs12_cache *c) { (void)x; (void)c; return (0); }
static void vmcs12_slot_reset(struct vmcs12_cache *c, uint64_t g) { memset(c, 0, sizeof(*c)); c->vmcs12_gpa = g; }
static void nested_bitmaps_unmap(struct vmcs12_cache *c) { (void)c; }
static void invvpid(uint64_t t, struct invvpid_desc d) { (void)t; (void)d; op.invvpid_hw++; }
static void nested_vpid02_request(struct vmx_nested *n) { (void)n; }
#define CAMPO_BANCO	0x6800u			/* il solo campo VMCS12 del banco (naturale, 64 bit) */
static bool nested_field_ok(struct vmx_vcpu *x, uint32_t f) { (void)x; return (f == CAMPO_BANCO); }
static uint64_t nested_field_mask(uint32_t f) { (void)f; return (~0ULL); }
static uint64_t vmcs12_read_field(struct vmcs12_cache *c, uint32_t f)
{
	int i = banco_shv_idx(f);
	return (i >= 0 ? c->shf[i] : c->campo);
}
static int vmcs12_write_field(struct vmcs12_cache *c, uint32_t f, uint64_t v)
{
	int i = banco_shv_idx(f);
	if (i >= 0) c->shf[i] = v; else c->campo = v;
	return (0);
}
/* lo shadow VMCS simulato: vmptrld/vmread/vmclear */
static int vmptrld(void *p) { (void)p; return (0); }
static int vmclear(void *p) { (void)p; return (0); }
static int vmread(uint32_t e, uint64_t *v) { int i = banco_shv_idx(e); if (op.vmread_err || i < 0) return (1); *v = op.shadow[i]; return (0); }
static void vm_suspend(void *vm, int how) { (void)vm; (void)how; op.sospesa++; }
static int vmx_vept_invept(struct vmx_vcpu *x, uint64_t t, uint64_t eptp, int *kept)
{
	(void)x; (void)t;
	op.invept_chiamate++;
	op.invept_eptp = eptp;
	*kept = 0;
	return (0);
}

/* prototipi delle funzioni estratte (l'ordine nel .inc e' quello dell'estrazione) */
int vm_set_register(struct vcpu *vcpu, int reg, uint64_t val);
static int vmmops_setreg(void *c, int reg, uint64_t val) { ((struct vmx_vcpu *)c)->vcpu->regs[reg] = val; return (0); }
static int nested_operand_gpa_at(struct vmx_vcpu *vcpu, int prot, uint64_t add, uint64_t *gpa);
static int nested_vmxon(struct vmx_vcpu *), nested_vmclear(struct vmx_vcpu *), nested_vmptrld(struct vmx_vcpu *),
    nested_vmptrst(struct vmx_vcpu *), nested_vmread(struct vmx_vcpu *), nested_vmwrite(struct vmx_vcpu *),
    nested_invvpid(struct vmx_vcpu *), nested_invept(struct vmx_vcpu *);

/* --- il guest: ingresso 0 = l'istruzione VMX (uscita NESTED); dopo, un'uscita che torna a userland (INOUT) */
#define RIP0	0x1000
#define LEN	5
static struct vmx vmx_banco;
static void *vmmops_vcpu_init(void *vm, struct vcpu *v, int id) { (void)vm; (void)id; xv.vcpu = v; xv.nested = &nn; xv.vmx = &vmx_banco; return (&xv); }
#define SHV_N		nitems(shv_fields)
static int vmmops_run(void *c, uint64_t rip, pmap_t p, struct vm_eventinfo *e)
{
	struct vcpu *v = ((struct vmx_vcpu *)c)->vcpu;
	int i = sc.entrate;

	(void)p; (void)e;
	sc.rip_entrata[i < 64 ? i : 63] = rip;
	if (++sc.entrate > 5000) {		/* il kernel vero arriverebbe al panic di nested_loops (2.000.000) */
		op.giro_illimitato = 1;
		longjmp(op.salto, 2);
	}
	memset(&v->exitinfo, 0, sizeof(v->exitinfo));
	v->exitinfo.rip = rip;
	v->regs[VM_REG_GUEST_RIP] = rip;	/* RIP del VMCS all'uscita */
	/*
	 * Un'eccezione iniettata dall'ultimo ingresso viene CONSEGNATA: l'L1 va al suo gestore (che qui esce verso
	 * userland). Senza eccezione, a RIP0 l'istruzione VMX si riesegue (una ripartenza senza causa gira).
	 */
	if (op.sospesa || (op.sosp_dopo && i >= 1)) {	/* vmx_run vede la sospensione (shv_fault -> vm_suspend) */
		v->exitinfo.exitcode = VM_EXITCODE_SUSPENDED;
		return (0);
	}
	if (rip == RIP0 && op.eccezioni == op.ecc_ingresso) {	/* l'istruzione VMX: esce NESTED (vmx.c:4267) */
		v->exitinfo.exitcode = VM_EXITCODE_NESTED;
		v->exitinfo.inst_length = LEN;
		v->exitinfo.u.vmx.exit_reason = op.motivo;	/* letto da vmx_nested_exit */
	} else
		v->exitinfo.exitcode = VM_EXITCODE_INOUT;
	op.ecc_ingresso = op.eccezioni;
	return (0);
}
/* --- vmx_nested_exit VERA (estratta): la tabella delle operazioni la chiama per VM_EXITCODE_NESTED (vmx.c:
 * ".nested_exit = vmx_nested_exit", verificato da run.sh); qui il suo prefisso e i gestori fuori perimetro */
int vmx_nested_exit(void *vcpui);
static int vmmops_nested_exit(void *c) { return (vmx_nested_exit(c)); }
static void nested_stats_flush(struct vmx_vcpu *x) { (void)x; op.flush++; }
static void vmx_vept_memgen_sync(struct vmx_vcpu *x) { (void)x; op.prefisso_altro++; }
static int nested_ept_emul_reflect(struct vmx_vcpu *x) { (void)x; op.prefisso_altro++; return (0); }
static int nested_ept_slow(struct vmx_vcpu *x) { (void)x; op.prefisso_altro++; return (0); }
static int shvmcs_pull_vera(struct vmx_vcpu *vcpu);
static int shvmcs_pull(struct vmx_vcpu *x) { op.shvmcs++; return (shvmcs_pull_vera(x)); }	/* passante che conta */
static int nested_vmxoff(struct vmx_vcpu *x) { (void)x; op.altri_gestori++; return (EINVAL); }
static int nested_vmlaunch(struct vmx_vcpu *x, bool r) { (void)x; (void)r; op.altri_gestori++; return (EINVAL); }
