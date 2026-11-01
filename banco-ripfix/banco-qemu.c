/*
 * banco-qemu.c -- Claude 30/10/2026, pareri #135 §5.1/§8 e #136 §3 (Q1-Q7 e mutanti del frontend). Usa
 * bhyve-vmrun-porta.h VERO (quello che QEMU compila) e lo stesso schema del ciclo di bhyve_vcpu_run: prima di ogni
 * VM_RUN si chiede bhyve_vmrun_puo_entrare (porta del vCPU E porta della VM); alla chiusura il primo vCPU chiude
 * la porta della VM. Il giro esterno continua anche dopo la chiusura (lo shutdown e' asincrono, o non arriva mai
 * con -no-shutdown) e non deve piu' arrivare a VM_RUN. Il kernel e' finto: una sequenza di errno per chiamata.
 */
#include <stdio.h>
#include <string.h>
#include "bhyve-vmrun-porta.h"

static int nf, nok;
#define VERO(c, ...) do { if (c) { nok++; } else { nf++; printf("  ERRATO  "); printf(__VA_ARGS__); \
	printf("  [%s]\n", #c); } } while (0)

/* un vCPU simulato */
typedef struct {
	BhyveVmrunPorta p;
	const int *seq;		/* errno di ogni VM_RUN (0 = riuscito); oltre la fine si ripete l'ultimo */
	int n, sosp, chiamate, arresti, motivo;
} Vcpu;

static BhyveVmrunVm vm;

/* un giro del thread del vCPU: true se ha chiamato VM_RUN */
static int giro(Vcpu *c, int id)
{
	int err, az;

#ifdef MUT_SENZA_PORTA_VM
	if (bhyve_vmrun_porta_chiusa(&c->p))
		return (0);
#else
	if (!bhyve_vmrun_puo_entrare(&c->p, &vm))
		return (0);			/* bhyve-all.c: porta chiusa -> MAI VM_RUN */
#endif
	err = c->seq[c->chiamate < c->n ? c->chiamate : c->n - 1];
	c->chiamate++;				/* VM_RUN */
	if (err == 0)
		return (1);
	az = bhyve_vmrun_errore(&c->p, err, c->sosp && err == EINVAL);
	if (az == BHYVE_VMRUN_RIPROVA)
		return (1);
	c->motivo = az;
	if (bhyve_vmrun_vm_chiudi(&vm, err, id))
		c->arresti++;			/* una sola richiesta d'arresto per la VM */
	return (1);
}

static Vcpu uno(const int *seq, int n, int sosp, int giri)
{
	Vcpu c;

	memset(&c, 0, sizeof(c));
	memset(&vm, 0, sizeof(vm));
	c.seq = seq; c.n = n; c.sosp = sosp;
	for (int g = 0; g < giri; g++)
		giro(&c, 0);
	return (c);
}

int main(void)
{
	Vcpu c;

	/* Q1 / Q7 / E12: ENOTRECOVERABLE, EFAULT (il DM col kernel vecchio), EIO: un errore, nessun secondo VM_RUN */
	{ int s[] = { ENOTRECOVERABLE }; c = uno(s, 1, 0, 1000); }
	VERO(c.chiamate == 1 && c.motivo == BHYVE_VMRUN_FATALE && c.arresti == 1, "Q1 ENOTRECOVERABLE chiamate %d", c.chiamate);
	{ int s[] = { 0, 0, EFAULT, 0 }; c = uno(s, 4, 0, 1000); }
	VERO(c.chiamate == 3 && c.motivo == BHYVE_VMRUN_FATALE && c.arresti == 1, "Q7 EFAULT chiamate %d", c.chiamate);
	{ int s[] = { EIO, 0 }; c = uno(s, 2, 0, 1000); }
	VERO(c.chiamate == 1 && c.motivo == BHYVE_VMRUN_FATALE, "Q1 EIO chiamate %d", c.chiamate);
	/* Q2: EINVAL sospeso -> SOSPESA al primo; EINVAL NON sospeso -> chiusa al primo (non dimostrato transitorio) */
	{ int s[] = { EINVAL }; c = uno(s, 1, 1, 100); }
	VERO(c.chiamate == 1 && c.motivo == BHYVE_VMRUN_SOSPESA, "Q2 sospeso chiamate %d motivo %d", c.chiamate, c.motivo);
	{ int s[] = { EINVAL, 0 }; c = uno(s, 2, 0, 100); }
	VERO(c.chiamate == 1 && c.motivo == BHYVE_VMRUN_NON_CLASSIFICATO, "Q2 non sospeso chiamate %d motivo %d", c.chiamate, c.motivo);
	/* Q3: ENOMEM, ENOSYS, EACCES, EBUSY, errno ignoto -> STOP al primo, non al 64esimo */
	{
		int e[] = { ENOMEM, ENOSYS, EACCES, EBUSY, 12345 };
		for (unsigned i = 0; i < sizeof(e) / sizeof(e[0]); i++) {
			int s[] = { e[i], 0 };
			c = uno(s, 2, 0, 100);
			VERO(c.chiamate == 1 && c.motivo == BHYVE_VMRUN_NON_CLASSIFICATO && c.p.chiusa_errno == e[i],
			    "Q3 errno %d chiamate %d", e[i], c.chiamate);
		}
	}
	/* Q4: EINTR ripetuti e intercalati a successi: nessuna chiusura spuria */
	{ int s[] = { EINTR }; c = uno(s, 1, 0, 1000); }
	VERO(c.chiamate == 1000 && c.p.chiusa_errno == 0 && !bhyve_vmrun_vm_chiusa(&vm), "Q4 EINTR chiamate %d", c.chiamate);
	{ int s[] = { EINTR, 0, EINTR, EINTR, 0, 0, EINTR }; c = uno(s, 7, 0, 7); }
	VERO(c.chiamate == 7 && c.p.chiusa_errno == 0, "Q4 intercalati chiusa %d", c.p.chiusa_errno);
	/* Q5: shutdown differito / -no-shutdown: il giro continua 100000 volte, la porta resta chiusa, 0 VM_RUN */
	{ int s[] = { EFAULT }; c = uno(s, 1, 0, 100000); }
	VERO(c.chiamate == 1, "Q5 chiamate %d dopo 100000 giri", c.chiamate);
	/* la porta non si riapre e conserva la diagnosi del primo errore */
	{
		BhyveVmrunPorta p;
		memset(&p, 0, sizeof(p));
		bhyve_vmrun_errore(&p, EFAULT, false);
		VERO(bhyve_vmrun_porta_chiusa(&p) && bhyve_vmrun_errore(&p, EINTR, false) == BHYVE_VMRUN_FATALE &&
		    p.chiusa_errno == EFAULT, "porta riaperta o diagnosi cambiata: errno %d", p.chiusa_errno);
	}
	/* Q6: due vCPU. Il vCPU 1 fallisce (EFAULT) alla terza chiamata mentre il vCPU 0 corre: da quel momento NESSUN
	 * vCPU chiama VM_RUN (il vCPU 0, uscito da vm_run col kick, si ferma alla porta della VM); un solo arresto */
	{
		int s0[] = { 0, EINTR, 0 }, s1[] = { 0, 0, EFAULT };
		Vcpu a, b;
		int dopo0 = 0, dopo1 = 0, chiusa = 0;

		memset(&a, 0, sizeof(a)); memset(&b, 0, sizeof(b)); memset(&vm, 0, sizeof(vm));
		a.seq = s0; a.n = 3; b.seq = s1; b.n = 3;
		for (int g = 0; g < 1000; g++) {
			int r0 = giro(&a, 0), r1 = giro(&b, 1);
			if (chiusa) {
				dopo0 += r0;
				dopo1 += r1;
			}
			if (bhyve_vmrun_vm_chiusa(&vm))
				chiusa = 1;
		}
		VERO(chiusa && dopo0 == 0 && dopo1 == 0 && a.arresti + b.arresti == 1 && vm.vcpu == 1 && vm.fatale_errno == EFAULT,
		    "Q6 VM_RUN dopo la chiusura: vCPU0 %d vCPU1 %d, arresti %d, chiusa da %d", dopo0, dopo1, a.arresti + b.arresti, vm.vcpu);
		VERO(!bhyve_vmrun_porta_chiusa(&a.p) && !bhyve_vmrun_puo_entrare(&a.p, &vm),
		    "Q6 il vCPU 0 ha la SUA porta aperta ma non puo' entrare");
	}
	/* chiusura concorrente della VM: solo il primo vince (una diagnosi, un arresto) */
	{
		memset(&vm, 0, sizeof(vm));
		int p1 = bhyve_vmrun_vm_chiudi(&vm, EFAULT, 3), p2 = bhyve_vmrun_vm_chiudi(&vm, EIO, 4);
		VERO(p1 && !p2 && vm.fatale_errno == EFAULT && vm.vcpu == 3, "VM chiusa due volte: %d %d", p1, p2);
	}
	printf("banco-qemu: %d ok, %d errati\n", nok, nf);
	return (nf != 0);
}
