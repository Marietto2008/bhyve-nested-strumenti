/*
 * ept_l0_repro.c -- Claude 26/10/2026, parere #68 opzione (c).
 *
 * Riproduttore dell'anomalia EPT02 sul percorso EPT ORDINARIO di bhyve
 * (guest normale, NON nested): pmap EPT + pm_eptgen + vmx_pmap_activate
 * (vmx.c) -> INVEPT single-context su vmx->eptp. NON passa per vmx_vept.c.
 *
 * Protocollo (una CPU: lanciare con `cpuset -l 6`):
 *   GPA X ha una memmap PROPRIA da 4 KB (vm_munmap_memseg vuole la
 *   corrispondenza esatta). A e B sono due pagine distinte del segmento.
 *   1. warm A : X -> A ; guest legge [X] in EAX ; VMCALL -> RAX = MAGIC_A
 *   2. A->B   : munmap X ; mmap X -> B   (pmap_remove -> pm_eptgen++;
 *               il prossimo ingresso fa INVEPT(SINGLE, vmx->eptp))
 *   3. read B : RAX DEVE essere MAGIC_B. MAGIC_A = anomalia riprodotta.
 *   4. non-present : munmap X (nessun remap)
 *   5. fault  : DEVE arrivare un'uscita con GPA = X (EPT violation su GPA non
 *               mappata -> VM_EXITCODE_INST_EMUL). Un VMCALL con un MAGIC =
 *               valore servito senza fault = anomalia riprodotta.
 *   6. ripete l'intera sequenza una seconda volta.
 *
 * Il verdetto passa SOLO dal GPR salvato al VM-exit (vm_get_register RAX) e
 * dal codice/GPA d'uscita: nessuna memoria condivisa come canale probatorio.
 * EPTP R e' stabile per costruzione: vmx->eptp e' assegnato una sola volta in
 * vmx_init (vmx.c:1267) e munmap/mmap non ricreano la radice del pmap.
 *
 * NON ESEGUIRE senza il via libera dell'utente (Fase 2 del parere #68).
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
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <vmmapi.h>

#define	VMNAME		"claude-eptrepro"
#define	SEGLEN		(1024 * 1024)		/* un solo segmento sysmem da 1 MB */
#define	CODE_GPA	0x1000UL		/* codice guest (modo reale) */
#define	X_GPA		0x20000UL		/* la GPA sonda, memmap propria 4 KB */
#define	OFF_A		0x20000UL		/* pagina A = offset del segmento */
#define	OFF_B		0x30000UL		/* pagina B = offset del segmento */
#define	MAGIC_A		0x41414141u
#define	MAGIC_B		0x42424242u
#define	PROT_GUEST	(PROT_READ | PROT_WRITE | PROT_EXEC)

static struct vmctx *ctx;
static int destroyed;

static void
cleanup(void)
{
	if (ctx != NULL && !destroyed) {
		destroyed = 1;
		vm_destroy(ctx);
	}
}

/* Mappa nel processo UNA pagina di memoria guest tramite il device vmm. */
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

/*
 * Una sonda: guest da RIP=CODE_GPA esegue
 *   mov ax,0x2000 ; mov ds,ax ; mov eax,[0] (= GPA X) ; vmcall
 * Ritorna l'exitcode; *rax e *gpa riempiti se pertinenti.
 */
static int
probe(struct vcpu *vcpu, uint64_t *rax, uint64_t *gpa, int *tries)
{
	struct vm_exit vme;
	struct vm_run vmrun;
	cpuset_t dmask;
	int n;

	if (vm_set_register(vcpu, VM_REG_GUEST_RIP, CODE_GPA) != 0)
		err(1, "set RIP");
	for (n = 1; n <= 64; n++) {
		memset(&vme, 0, sizeof(vme));
		vmrun.vm_exit = &vme;
		vmrun.cpuset = &dmask;
		vmrun.cpusetsize = sizeof(dmask);
		if (vm_run(vcpu, &vmrun) != 0) {
			if (errno == EINTR)
				continue;
			err(1, "vm_run");
		}
		switch (vme.exitcode) {
		case VM_EXITCODE_VMINSN:
		case VM_EXITCODE_VMX:		/* VMCALL del guest: valore in RAX */
			if (vm_get_register(vcpu, VM_REG_GUEST_RAX, rax) != 0)
				err(1, "get RAX");
			*tries = n;
			return (vme.exitcode);
		case VM_EXITCODE_INST_EMUL:	/* EPT violation su GPA non mappata */
			*gpa = vme.u.inst_emul.gpa;
			*tries = n;
			return (vme.exitcode);
		case VM_EXITCODE_BOGUS:
		case VM_EXITCODE_REQIDLE:
		case VM_EXITCODE_RENDEZVOUS:
			continue;		/* rientro neutro */
		default:
			*tries = n;
			return (vme.exitcode);	/* inatteso: lo riporta il chiamante */
		}
	}
	errx(1, "nessuna uscita utile in 64 ingressi");
}

static int fails;

static void
step_value(struct vcpu *vcpu, const char *tag, uint32_t expect)
{
	uint64_t rax = 0, gpa = 0;
	int ec, tries;

	ec = probe(vcpu, &rax, &gpa, &tries);
	if (ec == VM_EXITCODE_VMINSN || ec == VM_EXITCODE_VMX) {
		uint32_t v = (uint32_t)rax;
		const char *what = v == expect ? "PASS" :
		    v == MAGIC_A ? "FAIL (stantio: A)" :
		    v == MAGIC_B ? "FAIL (B inatteso)" : "FAIL (valore ignoto)";
		printf("%-14s exit=%d RAX=%#x atteso=%#x -> %s (ingressi %d)\n",
		    tag, ec, v, expect, what, tries);
		if (v != expect)
			fails++;
	} else {
		printf("%-14s exit=%d gpa=%#lx atteso VMCALL con %#x -> FAIL\n",
		    tag, ec, (unsigned long)gpa, expect);
		fails++;
	}
}

static void
step_fault(struct vcpu *vcpu, const char *tag)
{
	uint64_t rax = 0, gpa = 0;
	int ec, tries;

	ec = probe(vcpu, &rax, &gpa, &tries);
	if (ec == VM_EXITCODE_INST_EMUL && (gpa & ~(uint64_t)PAGE_MASK) == X_GPA) {
		printf("%-14s exit=INST_EMUL gpa=%#lx -> PASS (EPT violation su X)\n",
		    tag, (unsigned long)gpa);
	} else if (ec == VM_EXITCODE_VMINSN || ec == VM_EXITCODE_VMX) {
		printf("%-14s exit=VMCALL RAX=%#x -> FAIL (letto SENZA fault: "
		    "anomalia riprodotta)\n", tag, (uint32_t)rax);
		fails++;
	} else {
		printf("%-14s exit=%d gpa=%#lx -> FAIL (uscita inattesa)\n",
		    tag, ec, (unsigned long)gpa);
		fails++;
	}
}

int
main(void)
{
	static const uint8_t code[] = {
		0xb8, 0x00, 0x20,		/* mov ax, 0x2000          */
		0x8e, 0xd8,			/* mov ds, ax              */
		0x66, 0xa1, 0x00, 0x00,		/* mov eax, [0]  (= GPA X) */
		0x0f, 0x01, 0xc1,		/* vmcall                  */
		0xeb, 0xf7,			/* jmp -9 (rilegge)        */
	};
	struct vm_memseg ms;
	struct vcpu *vcpu;
	volatile uint32_t *pc, *pa, *pb;
	int round, i;

	if (vm_create(VMNAME) != 0)
		err(1, "vm_create %s", VMNAME);
	if ((ctx = vm_open(VMNAME)) == NULL)
		err(1, "vm_open");
	atexit(cleanup);
	if ((vcpu = vm_vcpu_open(ctx, 0)) == NULL)
		err(1, "vm_vcpu_open");

	/* un segmento sysmem (nome vuoto = sysmem), via ioctl: la libvmmapi di
	 * sistema non esporta vm_alloc_memseg */
	memset(&ms, 0, sizeof(ms));
	ms.segid = VM_SYSMEM;
	ms.len = SEGLEN;
	if (ioctl(vm_get_device_fd(ctx), VM_ALLOC_MEMSEG, &ms) != 0)
		err(1, "VM_ALLOC_MEMSEG");

	/* tre memmap: [0, X) | X (4 KB, propria) | (X+4K, 1MB) */
	if (vm_mmap_memseg(ctx, 0, VM_SYSMEM, 0, X_GPA, PROT_GUEST) != 0)
		err(1, "mmap bassa");
	if (vm_mmap_memseg(ctx, X_GPA, VM_SYSMEM, OFF_A, PAGE_SIZE,
	    PROT_GUEST) != 0)
		err(1, "mmap X->A");
	if (vm_mmap_memseg(ctx, X_GPA + PAGE_SIZE, VM_SYSMEM, X_GPA + PAGE_SIZE,
	    SEGLEN - X_GPA - PAGE_SIZE, PROT_GUEST) != 0)
		err(1, "mmap alta");

	/* contenuti: codice, A e B (B visibile all'host alla sua GPA identita') */
	pc = host_page(CODE_GPA);
	memcpy(__DEVOLATILE(void *, pc), code, sizeof(code));
	pa = host_page(X_GPA);
	pb = host_page(OFF_B);
	for (i = 0; i < PAGE_SIZE / 4; i++) {
		pa[i] = MAGIC_A;
		pb[i] = MAGIC_B;
	}

	/* vCPU in modo reale (unrestricted guest), CS base 0, RIP al codice */
	if (vm_set_capability(vcpu, VM_CAP_UNRESTRICTED_GUEST, 1) != 0)
		err(1, "VM_CAP_UNRESTRICTED_GUEST");
	if (vcpu_reset(vcpu) != 0)
		err(1, "vcpu_reset");
	if (vm_set_desc(vcpu, VM_REG_GUEST_CS, 0, 0xffff, 0x0093) != 0 ||
	    vm_set_register(vcpu, VM_REG_GUEST_CS, 0) != 0 ||
	    vm_set_register(vcpu, VM_REG_GUEST_RSP, 0x8000) != 0)
		err(1, "setup CS/RSP");

	printf("%s: X=%#lx A=off %#lx B=off %#lx MAGIC_A=%#x MAGIC_B=%#x\n",
	    VMNAME, X_GPA, OFF_A, OFF_B, MAGIC_A, MAGIC_B);

	for (round = 1; round <= 2; round++) {
		printf("--- giro %d ---\n", round);
		if (round == 2) {		/* rimette X -> A (memmap propria) */
			if (vm_mmap_memseg(ctx, X_GPA, VM_SYSMEM, OFF_A, PAGE_SIZE,
			    PROT_GUEST) != 0)
				err(1, "remap X->A");
		}
		step_value(vcpu, "1 warm A", MAGIC_A);
		step_value(vcpu, "1 warm A bis", MAGIC_A);

		/* 2. A->B sulla stessa GPA, stesso EPTP, vCPU fermo */
		if (vm_munmap_memseg(ctx, X_GPA, PAGE_SIZE) != 0)
			err(1, "munmap X (A)");
		if (vm_mmap_memseg(ctx, X_GPA, VM_SYSMEM, OFF_B, PAGE_SIZE,
		    PROT_GUEST) != 0)
			err(1, "mmap X->B");
		step_value(vcpu, "3 read B", MAGIC_B);

		/* 4. non-present */
		if (vm_munmap_memseg(ctx, X_GPA, PAGE_SIZE) != 0)
			err(1, "munmap X (B)");
		step_fault(vcpu, "5 fault X");
	}

	printf("RISULTATO: %s (%d fallimenti)\n", fails == 0 ? "PASS" : "FAIL",
	    fails);
	return (fails == 0 ? 0 : 2);
}
