# innesta-hcall.py -- claude 17/11/2026: registratore delle hypercall della partizione radice (Fable 042 par. 2.2, con le
# quattro correzioni della 067 par. 5.3), applicato all'albero del clone freebsd-nested-kvm, dopo i commit della 067 par. 3.
#   python3.12 innesta-hcall.py <radice del clone>
import sys
R = sys.argv[1] + '/sys/amd64/vmm/intel/'
assert 'hcall_attesa' not in open(R + 'vmx_nested.h').read(), 'gia\' applicato'


def una(p, old, new):
    s = open(R + p).read()
    assert s.count(old) == 1, (p, old[:70])
    open(R + p, 'w').write(s.replace(old, new))


una('vmx_nested.h',
    '\tint\t\tl2x_cpu;\t/* Fable 034 §4.1: CPU fisica dell\'ultima uscita dell\'L2 (dentro vmx_run) */\n',
    '\tint\t\tl2x_cpu;\t/* Fable 034 §4.1: CPU fisica dell\'ultima uscita dell\'L2 (dentro vmx_run) */\n'
    '\t/* 17/11 (Fable 042 par. 2.2): hypercall dell\'L2 in attesa del ritorno (registratore delle hypercall) */\n'
    '\tbool\t\thcall_attesa;\n'
    '\tuint64_t\thcall_vmcs12, hcall_rcx, hcall_rdx, hcall_r8;\n'
    '\tsbintime_t\thcall_t;\n')

CODICE = r'''
/*
 * 17/11/2026 (Fable 042 par. 2.2): registratore delle hypercall dell'L2 (con Hyper-V come L1: la partizione radice).
 * La rete di Windows che non parte (17/11 08:20, col valore 1: tabella MSI-X di virtio-net E dell'xHCI scritta con voci
 * vuote, addr 0 / data 0 / mascherata) e' una decisione della radice o di Hyper-V: qui si vede se la radice chiede la
 * mappatura degli interrupt di dispositivo (HvCallMapDeviceInterrupt 0x7C, Unmap 0x7D, Retarget 0x7E) e con quale
 * esito. All'uscita VMCALL riflessa (percorso veloce, sezione critica) si annotano solo RCX (codice e flag), RDX, R8 e
 * il VMCS12; al VMLAUNCH/VMRESUME seguente dello stesso vCPU SULLO STESSO VMCS12 (sullo stesso vCPU dell'L1 girano
 * anche i processori della VM di WSL), RAX dell'L1 e' il valore di ritorno: in VMX i registri generali passano all'L2
 * cosi' come sono. Per ogni codice: chiamate ed errori (stato = RAX[15:0] != 0); voci complete, con le prime 32 B delle
 * pagine d'ingresso (64 B: partizione, dispositivo, descrittore) e d'uscita (32 B: indirizzo e dato MSI restituiti) delle
 * chiamate lente, lette al ritorno (li' si puo' dormire), solo per 0x7C-0x7E e per gli errori. Le pagine sono GPA
 * dell'L2, tradotte con l'EPT12 del VMCS12 che si riprende (067 par. 5.3.2). Ogni voce porta l'EPTP12 (radice o VM di
 * WSL); nested_hcall_eptp (0 = tutti) limita l'anello a una base di EPTP, perche' gli errori normali delle hypercall
 * della VM di WSL non lo riempiano (067 par. 5.3.3). L'aggancio all'uscita sta in nested_reflect_to_l1, che serve
 * anche la riflessione dal percorso lento (slow_reflect): una VMCALL e' coperta da entrambe le strade.
 */
static int nested_hcall_reg = 1;
SYSCTL_INT(_hw_vmm_vmx, OID_AUTO, nested_hcall_reg, CTLFLAG_RWTUN, &nested_hcall_reg, 0,
    "nested: registratore delle hypercall dell'L2 (Fable 042 par. 2.2)");
static u_long nested_hcall_eptp = 0;
SYSCTL_ULONG(_hw_vmm_vmx, OID_AUTO, nested_hcall_eptp, CTLFLAG_RWTUN, &nested_hcall_eptp, 0,
    "nested: anello delle hypercall solo per questo EPTP12 (base, 0 = tutti)");
#define	HCALL_CODICI	0x200
#define	HCALL_VOCI	512
struct hcall_voce {
	sbintime_t	t;		/* uscita VMCALL */
	uint64_t	vmcs12, eptp12, rcx, rdx, r8, rax;
	uint64_t	ing[8], usc[4];	/* prime 64 / 32 B delle pagine (chiamate lente); 0 se non lette */
	uint32_t	us;		/* microsecondi fra uscita e ritorno */
	int		vcpu;
};
static u_long hcall_conta[HCALL_CODICI], hcall_errori[HCALL_CODICI];
static u_long hcall_oltre, hcall_senza_ritorno, hcall_voci_totali;
static struct hcall_voce hcall_anello[HCALL_VOCI];
static u_int hcall_testa;
static struct mtx hcall_mtx;
MTX_SYSINIT(nested_hcall_mtx, &hcall_mtx, "nested hcall", MTX_DEF);
SYSCTL_ULONG(_hw_vmm_vmx, OID_AUTO, nested_hcall_senza_ritorno, CTLFLAG_RD, &hcall_senza_ritorno, 0,
    "nested: VMCALL dell'L2 rimpiazzate prima di vederne il ritorno");
SYSCTL_ULONG(_hw_vmm_vmx, OID_AUTO, nested_hcall_voci, CTLFLAG_RD, &hcall_voci_totali, 0,
    "nested: voci complete registrate (0x7C-0x7E ed errori), anche quelle uscite dall'anello");

static int
sysctl_hcall_codici(SYSCTL_HANDLER_ARGS)
{
	struct sbuf sb;
	int error, i;

	sbuf_new_for_sysctl(&sb, NULL, 1024, req);
	for (i = 0; i < HCALL_CODICI; i++)
		if (hcall_conta[i] != 0)
			sbuf_printf(&sb, "%#x:%lu/%lu ", i, hcall_conta[i], hcall_errori[i]);
	sbuf_printf(&sb, "oltre:%lu", hcall_oltre);
	error = sbuf_finish(&sb);
	sbuf_delete(&sb);
	return (error);
}
SYSCTL_PROC(_hw_vmm_vmx, OID_AUTO, nested_hcall_codici, CTLTYPE_STRING | CTLFLAG_RD | CTLFLAG_MPSAFE, NULL, 0,
    sysctl_hcall_codici, "A", "nested: hypercall dell'L2 per codice, codice:chiamate/errori");

static int
sysctl_hcall_anello(SYSCTL_HANDLER_ARGS)
{
	struct sbuf sb;
	struct hcall_voce v;
	u_int k, n, testa;
	int error;

	sbuf_new_for_sysctl(&sb, NULL, 4096, req);
	mtx_lock(&hcall_mtx);
	testa = hcall_testa;
	mtx_unlock(&hcall_mtx);
	n = testa < HCALL_VOCI ? testa : HCALL_VOCI;
	for (k = testa - n; k != testa; k++) {
		mtx_lock(&hcall_mtx);
		v = hcall_anello[k % HCALL_VOCI];
		mtx_unlock(&hcall_mtx);
		sbuf_printf(&sb, "t=%ld.%06ld vcpu%d vmcs12=%#lx eptp12=%#lx codice=%#lx rcx=%#lx rdx=%#lx r8=%#lx "
		    "stato=%#lx rax=%#lx us=%u ing=%016lx.%016lx.%016lx.%016lx.%016lx.%016lx.%016lx.%016lx "
		    "usc=%016lx.%016lx.%016lx.%016lx\n",
		    (long)(v.t >> 32), (long)(((v.t & 0xffffffff) * 1000000) >> 32), v.vcpu, (u_long)v.vmcs12,
		    (u_long)v.eptp12, (u_long)(v.rcx & 0xffff), (u_long)v.rcx, (u_long)v.rdx, (u_long)v.r8,
		    (u_long)(v.rax & 0xffff), (u_long)v.rax, v.us, (u_long)v.ing[0], (u_long)v.ing[1], (u_long)v.ing[2],
		    (u_long)v.ing[3], (u_long)v.ing[4], (u_long)v.ing[5], (u_long)v.ing[6], (u_long)v.ing[7],
		    (u_long)v.usc[0], (u_long)v.usc[1], (u_long)v.usc[2], (u_long)v.usc[3]);
	}
	error = sbuf_finish(&sb);
	sbuf_delete(&sb);
	return (error);
}
SYSCTL_PROC(_hw_vmm_vmx, OID_AUTO, nested_hcall_anello, CTLTYPE_STRING | CTLFLAG_RD | CTLFLAG_MPSAFE, NULL, 0,
    sysctl_hcall_anello, "A", "nested: ultime voci complete (0x7C-0x7E ed errori), dalla piu' vecchia");

static int
sysctl_hcall_azzera(SYSCTL_HANDLER_ARGS)
{
	int error, v = 0;

	error = sysctl_handle_int(oidp, &v, 0, req);
	if (error != 0 || req->newptr == NULL || v != 1)
		return (error);
	mtx_lock(&hcall_mtx);
	memset(hcall_conta, 0, sizeof(hcall_conta));
	memset(hcall_errori, 0, sizeof(hcall_errori));
	hcall_oltre = hcall_senza_ritorno = hcall_voci_totali = 0;
	hcall_testa = 0;
	mtx_unlock(&hcall_mtx);
	return (0);
}
SYSCTL_PROC(_hw_vmm_vmx, OID_AUTO, nested_hcall_azzera, CTLTYPE_INT | CTLFLAG_RW | CTLFLAG_MPSAFE, NULL, 0,
    sysctl_hcall_azzera, "I", "nested: scrivere 1 azzera contatori e anello delle hypercall");

/* uscita VMCALL dell'L2 riflessa all'L1: percorso veloce, solo registri */
static void
nested_hcall_uscita(struct vmx_vcpu *vcpu, struct vmcs12_cache *c)
{
	struct vmx_nested *n = vcpu->nested;

	if (n->hcall_attesa)
		atomic_add_long(&hcall_senza_ritorno, 1);
	n->hcall_attesa = true;
	n->hcall_vmcs12 = c->vmcs12_gpa;
	n->hcall_rcx = vcpu->ctx.guest_rcx;
	n->hcall_rdx = vcpu->ctx.guest_rdx;
	n->hcall_r8 = vcpu->ctx.guest_r8;
	n->hcall_t = sbinuptime();
}

/* len byte dalla pagina dell'L2 a l2gpa: tradotta con l'EPT12 (eptp12 != 0) o presa com'e' (L2 senza EPT) */
static void
nested_hcall_pagina(struct vmx_vcpu *vcpu, uint64_t eptp12, uint64_t l2gpa, uint64_t *dst, int len)
{
	void *cookie;
	uint64_t *p, gpa;

	if ((l2gpa & PAGE_MASK) > PAGE_SIZE - len)
		return;
	if (eptp12 == 0)
		gpa = l2gpa;
	else if (vmx_vept_l2_a_l1(vcpu, eptp12, l2gpa, &gpa) != 0)
		return;
	p = vm_gpa_hold(vcpu->vcpu, gpa, len, VM_PROT_READ, &cookie);
	if (p == NULL)
		return;
	memcpy(dst, p, len);
	vm_gpa_release(cookie);
}

/* VMLAUNCH/VMRESUME dell'L1 verso l'L2 (qui si puo' dormire): ritorno della hypercall in attesa sullo stesso VMCS12 */
static void
nested_hcall_ritorno(struct vmx_vcpu *vcpu, struct vmcs12_cache *c)
{
	struct vmx_nested *n = vcpu->nested;
	struct hcall_voce v;
	uint32_t codice;
	uint64_t rax;

	if (!n->hcall_attesa || c->vmcs12_gpa != n->hcall_vmcs12)
		return;
	n->hcall_attesa = false;
	rax = vcpu->ctx.guest_rax;
	codice = n->hcall_rcx & 0xffff;
	if (codice < HCALL_CODICI) {
		atomic_add_long(&hcall_conta[codice], 1);
		if ((rax & 0xffff) != 0)
			atomic_add_long(&hcall_errori[codice], 1);
	} else
		atomic_add_long(&hcall_oltre, 1);
	if (!((codice >= 0x7c && codice <= 0x7e) || (rax & 0xffff) != 0))
		return;
	memset(&v, 0, sizeof(v));
	v.t = n->hcall_t;
	v.vmcs12 = n->hcall_vmcs12;
	v.rcx = n->hcall_rcx;
	v.rdx = n->hcall_rdx;
	v.r8 = n->hcall_r8;
	v.rax = rax;
	v.us = (uint32_t)((sbinuptime() - n->hcall_t) / SBT_1US);
	v.vcpu = vcpu->vcpuid;
	v.eptp12 = (vmcs12_proc2(c) & PROCBASED2_ENABLE_EPT) != 0 ? vmcs12_read_field(c, VMCS_EPTP) : 0;
	if (nested_hcall_eptp != 0 && (v.eptp12 & ~(uint64_t)PAGE_MASK) != (nested_hcall_eptp & ~(u_long)PAGE_MASK))
		return;			/* 067 par. 5.3.3: anello limitato a un EPTP12 */
	if ((n->hcall_rcx & (1ul << 16)) == 0) {	/* chiamata lenta: RDX e R8 sono le pagine */
		nested_hcall_pagina(vcpu, v.eptp12, n->hcall_rdx, v.ing, sizeof(v.ing));
		nested_hcall_pagina(vcpu, v.eptp12, n->hcall_r8, v.usc, sizeof(v.usc));
	}
	mtx_lock(&hcall_mtx);
	hcall_anello[hcall_testa % HCALL_VOCI] = v;
	hcall_testa++;
	hcall_voci_totali++;
	mtx_unlock(&hcall_mtx);
}
'''

una('vmx_nested.c',
    'static u_int nested_diag_oprec_every = 0;\n',
    CODICE.lstrip('\n') + '\nstatic u_int nested_diag_oprec_every = 0;\n')
# uscita: prima del blocco del registratore delle operazioni, dopo il motivo d'uscita completo
una('vmx_nested.c',
    '''	/* Fable 018 §4.1: la riflessione nell'anello (VMCS02 corrente) */
	if (__predict_false(nested_diag_oprec != 0)) {
		nested_oprec_note(vcpu->nested, OPR_RIFL,''',
    '''	/* 17/11 (Fable 042 par. 2.2): VMCALL dell'L2, in attesa del ritorno */
	if (nested_hcall_reg != 0 &&
	    (vmexit->u.vmx.exit_reason & 0xffff) == EXIT_REASON_VMCALL)
		nested_hcall_uscita(vcpu, c);
	/* Fable 018 §4.1: la riflessione nell'anello (VMCS02 corrente) */
	if (__predict_false(nested_diag_oprec != 0)) {
		nested_oprec_note(vcpu->nested, OPR_RIFL,''')
# ritorno: dove si puo' dormire, prima della radice shadow
una('vmx_nested.c',
    '''	/* Shadow EPT: radice preparata QUI, dove si puo' dormire. Da VMPTRLD
	 * in poi si e' in sezione critica (niente malloc ne' vm_gpa_hold). */
''',
    '''	/* 17/11 (Fable 042 par. 2.2): ritorno della hypercall dell'L2 (RAX dell'L1) */
	if (n->hcall_attesa)
		nested_hcall_ritorno(vcpu, c);
	/* Shadow EPT: radice preparata QUI, dove si puo' dormire. Da VMPTRLD
	 * in poi si e' in sezione critica (niente malloc ne' vm_gpa_hold). */
''')
una('vmx_nested.h',
    "void\tvmx_vept_prepare(struct vmx_vcpu *vcpu);\t/* puo' dormire */\n",
    "void\tvmx_vept_prepare(struct vmx_vcpu *vcpu);\t/* puo' dormire */\n"
    "int\tvmx_vept_l2_a_l1(struct vmx_vcpu *vcpu, uint64_t eptp12, uint64_t l2gpa,\n"
    "\t    uint64_t *l1gpa);\t/* 067 par. 5.3.2: registratore delle hypercall */\n")
una('vmx_vept.c',
    "/*\n * Fase A2 (parere Astra 012): accende i flag A/D",
    "/*\n * 17/11 (Fable 067 par. 5.3.2): GPA dell'L2 -> GPA dell'L1 con un EPTP12 dato, per il registratore delle\n"
    " * hypercall (pagine d'ingresso e d'uscita). Solo lettura dell'EPT12, nessuna fotografia; puo' dormire.\n */\n"
    "int\nvmx_vept_l2_a_l1(struct vmx_vcpu *vcpu, uint64_t eptp12, uint64_t l2gpa, uint64_t *l1gpa)\n{\n"
    "\tuint64_t perm;\n\n"
    "\tif (ept12_translate(vcpu, eptp12, l2gpa, l1gpa, &perm, NULL) != VEPT_OK || (perm & EPT_PG_READ) == 0)\n"
    "\t\treturn (-1);\n\treturn (0);\n}\n\n"
    "/*\n * Fase A2 (parere Astra 012): accende i flag A/D")
print('innestato')
