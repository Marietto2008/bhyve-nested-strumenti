/*
 * ept_l0_repro.c -- Claude 26/10/2026, parere #68 opzione (c), v4 (pareri #69/#70).
 *
 * v4: vm_activate_cpu() prima del primo vm_run (lo smoke v3 era INVALID:
 * vm_run -> EINVAL perche' il vCPU non era in active_cpus).
 *
 * v3 (parere #70): handler di segnale async-signal-safe (solo un flag; la VM si
 * distrugge fuori dall'handler, uscita normale + atexit), sigaction senza
 * SA_RESTART; confronto EAX esplicitamente a 32 bit con log di RAX completo;
 * verdetti separati HARNESS_PROTOCOL e HW_EPT_NONPRESENT; stdout a buffer di riga.
 *
 * Riproduttore dell'anomalia EPT02 sul percorso EPT ORDINARIO di bhyve
 * (guest normale, NON nested): pmap EPT + pm_eptgen + vmx_pmap_activate
 * (vmx.c) -> INVEPT single-context su vmx->eptp. NON passa per vmx_vept.c.
 *
 * v2: l'uscita dal guest e' un OUT su porta NON gestita dal kernel, non piu'
 * un VMCALL. Verificato su vmm.c:1347-1350 della build in uso: VM_EXITCODE_VMINSN
 * (VMCALL di un guest non-nested) viene trattato in kernel con vm_inject_ud() e
 * NON arriva in userspace. Invece vmm_ioport.c (emulate_inout_port) manda in
 * userspace ogni porta >= MAX_IOPORTS (1280) o senza handler: 0xEEEF e' libera.
 *
 * Guest (modo reale, unrestricted guest), a GPA 0x1000 (disassemblato i8086):
 *   1000: mov ax,0x2000      1005: mov dx,0xeeef      1008: mov eax,[0]   (= GPA X)
 *   1003: mov ds,ax          100c: out dx,eax  (EAX intatto)   100e: jmp 1008
 *
 * Esiti (parere #69 §7): PASS / FAIL_EPT / INVALID. Ogni uscita diversa da
 * quella attesa e' INVALID, mai PASS.
 *
 *   ./ept_l0_repro smoke   -> solo passo 0 (una lettura di A + OUT)
 *   ./ept_l0_repro         -> passo 0 (abort se non PASS), poi 2 giri A->B->non-present
 *
 * Lanciare con `cpuset -l 6` e un timeout esterno. NON ESEGUIRE senza il via
 * libera dell'utente (Fase 2).
 */
#include <sys/param.h>
#include <sys/cpuset.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

#include <machine/vmm.h>
#include <machine/vmm_dev.h>
#include <dev/vmm/vmm_mem.h>

#include <err.h>
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <vmmapi.h>

#define	VMNAME		"claude-eptrepro"
#define	SEGLEN		(1024 * 1024)
#define	CODE_GPA	0x1000UL
#define	X_GPA		0x20000UL		/* GPA sonda: memmap propria da 4 KB */
#define	OFF_A		0x20000UL
#define	OFF_B		0x30000UL
#define	MAGIC_A		0x41414141u
#define	MAGIC_B		0x42424242u
#define	TEST_PORT	0xeeef
#define	PROT_GUEST	(PROT_READ | PROT_WRITE | PROT_EXEC)

enum outcome { R_OUT, R_FAULT_X, R_EFAULT, R_OTHER, R_STOP };
enum verdict { V_PASS, V_FAIL_EPT, V_INVALID };

static struct vmctx *ctx;
static volatile sig_atomic_t created, destroyed;
/* v3 (parere #70 §5): l'handler di segnale si limita a questo flag; la
 * distruzione della VM avviene fuori dall'handler (uscita normale + atexit). */
static volatile sig_atomic_t stop_sig;
static volatile uint32_t *pa, *pb;
static int n_fail_ept, n_invalid;

/* Distrugge SOLO la VM che questo processo ha creato, una volta sola. */
static void
cleanup(void)
{
	if (ctx != NULL && created && !destroyed) {
		destroyed = 1;
		vm_destroy(ctx);
	}
}

/* Async-signal-safe: solo un'assegnazione a sig_atomic_t. */
static void
on_signal(int sig)
{
	stop_sig = sig;
}

/* Uscita ordinaria dopo un segnale: atexit(cleanup) distrugge la VM. */
static void
stop_if_requested(void)
{
	if (stop_sig != 0) {
		printf("RISULTATO: INVALID (interrotto dal segnale %d)\n",
		    (int)stop_sig);
		printf("HARNESS_PROTOCOL=INVALID\n");
		exit(128 + (int)stop_sig);
	}
}

static volatile uint32_t *
host_page(vm_paddr_t gpa)
{
	void *p;

	p = mmap(NULL, PAGE_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
	    vm_get_device_fd(ctx), (off_t)gpa);
	if (p == MAP_FAILED)
		err(1, "mmap host della GPA %#lx", (unsigned long)gpa);
	return ((volatile uint32_t *)p);
}

/* Le due pagine devono avere ancora i loro marcatori, senza contaminazioni. */
static int
markers_ok(const char *when)
{
	int i, ok = 1;

	for (i = 0; i < PAGE_SIZE / 4; i++) {
		if (pa[i] != MAGIC_A || pb[i] != MAGIC_B) {
			ok = 0;
			break;
		}
	}
	printf("  [host] marcatori %s: %s (A[0]=%#x B[0]=%#x)\n", when,
	    ok ? "integri" : "ALTERATI", pa[0], pb[0]);
	return (ok);
}

/*
 * Una sonda: RIP=0x1000, il guest legge [X] e fa OUT. Classifica l'uscita.
 * *val = EAX dell'OUT; *gpa = GPA del fault; *ec = exitcode; *eno = errno.
 */
static enum outcome
probe(struct vcpu *vcpu, uint32_t *val, uint64_t *gpa, int *ec, int *eno)
{
	struct vm_exit vme;
	struct vm_run vmrun;
	cpuset_t dmask;
	uint64_t rax;
	int n;

	*ec = -1;
	*eno = 0;
	if (vm_set_register(vcpu, VM_REG_GUEST_RIP, CODE_GPA) != 0)
		err(1, "set RIP");
	for (n = 0; n < 64; n++) {
		if (stop_sig != 0)
			return (R_STOP);
		memset(&vme, 0, sizeof(vme));
		vmrun.vm_exit = &vme;
		vmrun.cpuset = &dmask;
		vmrun.cpusetsize = sizeof(dmask);
		if (vm_run(vcpu, &vmrun) != 0) {
			if (errno == EINTR)
				continue;	/* il flag si ricontrolla in testa */
			*eno = errno;
			return (R_EFAULT);
		}
		*ec = vme.exitcode;
		switch (vme.exitcode) {
		case VM_EXITCODE_INOUT:
			if (vme.u.inout.port != TEST_PORT || vme.u.inout.in ||
			    vme.u.inout.bytes != 4 || vme.u.inout.string) {
				printf("  [run] INOUT inatteso: port=%#x in=%d "
				    "bytes=%d str=%d\n", vme.u.inout.port,
				    vme.u.inout.in, vme.u.inout.bytes,
				    vme.u.inout.string);
				return (R_OTHER);
			}
			if (vm_get_register(vcpu, VM_REG_GUEST_RAX, &rax) != 0)
				err(1, "get RAX");
			/* parere #70 §3.2: OUT a 4 byte -> si confrontano solo i
			 * 32 bit bassi; il log mostra RAX intero per l'audit */
			printf("  [run] INOUT port=%#x out bytes=4: RAX=%#018lx "
			    "EAX=%#x inout.eax=%#x\n", vme.u.inout.port,
			    (unsigned long)rax, (uint32_t)rax, vme.u.inout.eax);
			if ((uint32_t)rax != (uint32_t)vme.u.inout.eax) {
				printf("  [run] RAX %#x != inout.eax %#x\n",
				    (uint32_t)rax, vme.u.inout.eax);
				return (R_OTHER);
			}
			*val = vme.u.inout.eax;
			return (R_OUT);
		case VM_EXITCODE_INST_EMUL:
			*gpa = vme.u.inst_emul.gpa;
			return (R_FAULT_X);	/* il chiamante verifica gpa == X */
		case VM_EXITCODE_BOGUS:
		case VM_EXITCODE_REQIDLE:
		case VM_EXITCODE_RENDEZVOUS:
			continue;		/* rientri neutri */
		default:
			return (R_OTHER);
		}
	}
	return (R_OTHER);			/* 64 rientri senza uscita utile */
}

static enum verdict
expect_value(struct vcpu *vcpu, const char *tag, uint32_t expect)
{
	uint64_t gpa = 0;
	uint32_t val = 0;
	enum outcome o;
	enum verdict v;
	int ec, eno;

	o = probe(vcpu, &val, &gpa, &ec, &eno);
	if (o == R_STOP)
		stop_if_requested();
	if (o == R_OUT && val == expect)
		v = V_PASS;
	else if (o == R_OUT && expect == MAGIC_B && val == MAGIC_A)
		v = V_FAIL_EPT;			/* A stantio dopo A->B */
	else
		v = V_INVALID;
	printf("%-16s esito=%d exit=%d val=%#x gpa=%#lx errno=%d atteso=%#x "
	    "-> %s\n", tag, o, ec, val, (unsigned long)gpa, eno, expect,
	    v == V_PASS ? "PASS" : v == V_FAIL_EPT ? "FAIL_EPT (A stantio)" :
	    "INVALID");
	if (v == V_FAIL_EPT)
		n_fail_ept++;
	if (v == V_INVALID)
		n_invalid++;
	return (v);
}

static enum verdict
expect_fault(struct vcpu *vcpu, const char *tag)
{
	uint64_t gpa = 0;
	uint32_t val = 0;
	enum outcome o;
	enum verdict v;
	int ec, eno;

	o = probe(vcpu, &val, &gpa, &ec, &eno);
	if (o == R_STOP)
		stop_if_requested();
	if (o == R_FAULT_X && (gpa & ~(uint64_t)PAGE_MASK) == X_GPA)
		v = V_PASS;
	else if (o == R_OUT && (val == MAGIC_A || val == MAGIC_B))
		v = V_FAIL_EPT;			/* letto SENZA fault */
	else
		v = V_INVALID;			/* incl. EFAULT: va diagnosticato */
	printf("%-16s esito=%d exit=%d val=%#x gpa=%#lx errno=%d atteso=fault X "
	    "-> %s\n", tag, o, ec, val, (unsigned long)gpa, eno,
	    v == V_PASS ? "PASS (fault su X)" :
	    v == V_FAIL_EPT ? "FAIL_EPT (letto senza fault)" : "INVALID");
	if (v == V_FAIL_EPT)
		n_fail_ept++;
	if (v == V_INVALID)
		n_invalid++;
	return (v);
}

int
main(int argc, char **argv)
{
	static const uint8_t code[] = {
		0xb8, 0x00, 0x20,		/* mov ax, 0x2000          */
		0x8e, 0xd8,			/* mov ds, ax              */
		0xba, 0xef, 0xee,		/* mov dx, 0xeeef          */
		0x66, 0xa1, 0x00, 0x00,		/* mov eax, [0]  (= GPA X) */
		0x66, 0xef,			/* out dx, eax             */
		0xeb, 0xf8,			/* jmp 0x1008              */
	};
	struct vm_memseg ms;
	struct vcpu *vcpu;
	volatile uint32_t *pc;
	struct vmctx *other;
	int smoke, round, i;

	/* log su file: a buffer di riga, cosi' sopravvive anche a un SIGKILL */
	setvbuf(stdout, NULL, _IOLBF, 0);
	smoke = (argc > 1 && strcmp(argv[1], "smoke") == 0);

	/* Nome riservato: se esiste gia' una VM con questo nome, NON la tocco. */
	if ((other = vm_open(VMNAME)) != NULL)
		errx(3, "esiste gia' una VM '%s': non la tocco, mi fermo", VMNAME);
	if (vm_create(VMNAME) != 0)
		err(3, "vm_create %s", VMNAME);
	created = 1;
	if ((ctx = vm_open(VMNAME)) == NULL)
		err(3, "vm_open");
	atexit(cleanup);
	{
		struct sigaction sa;

		memset(&sa, 0, sizeof(sa));
		sa.sa_handler = on_signal;	/* solo stop_sig = sig */
		sigemptyset(&sa.sa_mask);
		sa.sa_flags = 0;		/* niente SA_RESTART: vm_run torna */
		if (sigaction(SIGINT, &sa, NULL) != 0 ||
		    sigaction(SIGTERM, &sa, NULL) != 0 ||
		    sigaction(SIGHUP, &sa, NULL) != 0)
			err(3, "sigaction");
	}
	if ((vcpu = vm_vcpu_open(ctx, 0)) == NULL)
		err(3, "vm_vcpu_open");

	memset(&ms, 0, sizeof(ms));
	ms.segid = VM_SYSMEM;
	ms.len = SEGLEN;
	if (ioctl(vm_get_device_fd(ctx), VM_ALLOC_MEMSEG, &ms) != 0)
		err(3, "VM_ALLOC_MEMSEG");
	if (vm_mmap_memseg(ctx, 0, VM_SYSMEM, 0, X_GPA, PROT_GUEST) != 0)
		err(3, "mmap bassa");
	if (vm_mmap_memseg(ctx, X_GPA, VM_SYSMEM, OFF_A, PAGE_SIZE,
	    PROT_GUEST) != 0)
		err(3, "mmap X->A");
	if (vm_mmap_memseg(ctx, X_GPA + PAGE_SIZE, VM_SYSMEM, X_GPA + PAGE_SIZE,
	    SEGLEN - X_GPA - PAGE_SIZE, PROT_GUEST) != 0)
		err(3, "mmap alta");

	pc = host_page(CODE_GPA);
	memcpy(__DEVOLATILE(void *, pc), code, sizeof(code));
	pa = host_page(X_GPA);			/* A: finche' X -> A */
	pb = host_page(OFF_B);			/* B: alla sua GPA identita' */
	for (i = 0; i < PAGE_SIZE / 4; i++) {
		pa[i] = MAGIC_A;
		pb[i] = MAGIC_B;
	}

	if (vm_set_capability(vcpu, VM_CAP_UNRESTRICTED_GUEST, 1) != 0)
		err(3, "VM_CAP_UNRESTRICTED_GUEST");
	if (vcpu_reset(vcpu) != 0)
		err(3, "vcpu_reset");
	if (vm_set_desc(vcpu, VM_REG_GUEST_CS, 0, 0xffff, 0x0093) != 0 ||
	    vm_set_register(vcpu, VM_REG_GUEST_CS, 0) != 0 ||
	    vm_set_register(vcpu, VM_REG_GUEST_RSP, 0x8000) != 0)
		err(3, "setup CS/RSP");
	/* v4: senza attivazione vm_run() torna EINVAL (vmm.c: vcpuid non in
	 * active_cpus) -- smoke v3 INVALID con errno=22. bhyve(8) lo fa sempre
	 * (bhyverun.c:639). */
	if (vm_activate_cpu(vcpu) != 0)
		err(3, "vm_activate_cpu");

	printf("%s v4: X=%#lx A=off %#lx B=off %#lx porta=%#x pid=%d\n",
	    VMNAME, X_GPA, OFF_A, OFF_B, TEST_PORT, (int)getpid());
	markers_ok("iniziali");

	/* Passo 0: smoke del canale userspace. Se non e' PASS, si ferma tutto. */
	if (expect_value(vcpu, "0 smoke A", MAGIC_A) != V_PASS) {
		printf("RISULTATO: INVALID (canale userspace non verificato)\n");
		printf("HARNESS_PROTOCOL=INVALID\n");
		return (3);
	}
	if (smoke) {
		printf("RISULTATO: SMOKE PASS\n");
		printf("HARNESS_PROTOCOL=PASS\n");
		return (0);
	}

	for (round = 1; round <= 2; round++) {
		printf("--- giro %d ---\n", round);
		if (round == 2 && vm_mmap_memseg(ctx, X_GPA, VM_SYSMEM, OFF_A,
		    PAGE_SIZE, PROT_GUEST) != 0)
			err(3, "remap X->A");
		expect_value(vcpu, "1 warm A", MAGIC_A);
		expect_value(vcpu, "1 warm A bis", MAGIC_A);

		if (vm_munmap_memseg(ctx, X_GPA, PAGE_SIZE) != 0)
			err(3, "munmap X (A)");
		if (vm_mmap_memseg(ctx, X_GPA, VM_SYSMEM, OFF_B, PAGE_SIZE,
		    PROT_GUEST) != 0)
			err(3, "mmap X->B");
		if (!markers_ok("dopo X->B"))
			n_invalid++;
		expect_value(vcpu, "2 read B", MAGIC_B);

		if (vm_munmap_memseg(ctx, X_GPA, PAGE_SIZE) != 0)
			err(3, "munmap X (B)");
		if (!markers_ok("dopo non-present"))
			n_invalid++;
		expect_fault(vcpu, "3 fault X");
	}

	if (n_invalid > 0)
		printf("RISULTATO: INVALID (%d invalidi, %d fail_ept)\n",
		    n_invalid, n_fail_ept);
	else if (n_fail_ept > 0)
		printf("RISULTATO: FAIL_EPT (%d)\n", n_fail_ept);
	else
		printf("RISULTATO: PASS\n");
	/* parere #70 §3.3: due verdetti distinti. Il programma vede solo il
	 * contratto userspace; la reason 48 hardware su X la vede il DTrace. */
	printf("HARNESS_PROTOCOL=%s\n", n_invalid > 0 ? "INVALID" : "PASS");
	printf("HW_EPT_NONPRESENT=UNKNOWN (dal programma; si decide con la "
	    "traccia DTrace: reason48 su GPA %#lx al passo 3)\n", X_GPA);
	return (n_invalid > 0 ? 3 : n_fail_ept > 0 ? 2 : 0);
}
