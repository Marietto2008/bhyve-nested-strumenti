/*
 * banco-q8.c -- Claude 30/10/2026, parere #139 §5 (Q8). Concorrenza VERA (pthread) della porta della VM, con le
 * funzioni VERE di bhyve-vmrun-porta.h. Il VM_RUN e' finto (un'attesa); conta l'ingresso e se la porta era gia'
 * chiusa all'ingresso.
 *   Q8a  A/B/A forzato: A ammesso -> barriera -> B chiude e legge in_volo -> barriera -> A entra. Contratto: B
 *        DEVE vedere A in volo (A e' un ammesso PRIMA della chiusura), dopo il drain in_volo = 0, A non e' piu'
 *        ammesso.
 *   Q8b  B/A: B chiude, poi A chiede: rifiutato, nessun ingresso.
 *   Q8c  stress: 8 vCPU per molti giri, chiusura a caso; dopo la QUIESCENZA (in_volo == 0 osservato da chi chiude)
 *        nessun VM_RUN inizia; gli ingressi iniziati con la porta gia' chiusa non superano il numero in volo letto
 *        da chi ha chiuso.
 * MUT_SOLO_CONTROLLO: il vecchio schema (solo controllo, niente in_volo) -> Q8a deve fallire.
 */
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "bhyve-vmrun-porta.h"

#ifdef MUT_SOLO_CONTROLLO
#define AMMETTI(p, vm)	bhyve_vmrun_puo_entrare(p, vm)
#define USCITO(vm)	do { } while (0)
#else
#define AMMETTI(p, vm)	bhyve_vmrun_ammetti(p, vm)
#define USCITO(vm)	bhyve_vmrun_uscito(vm)
#endif

static int nf, nok;
#define VERO(c, ...) do { if (c) { nok++; } else { nf++; printf("  ERRATO  "); printf(__VA_ARGS__); \
	printf("  [%s]\n", #c); } } while (0)

static BhyveVmrunVm vm;
static pthread_barrier_t b1, b2;
static int a_entrato, a_vedeva_chiusa, b_vede_in_volo;

static void *thr_a(void *x)
{
	BhyveVmrunPorta p;
	(void)x;
	memset(&p, 0, sizeof(p));
	if (AMMETTI(&p, &vm)) {
		pthread_barrier_wait(&b1);		/* ammesso, non ancora in VM_RUN */
		pthread_barrier_wait(&b2);		/* B ha chiuso */
		a_vedeva_chiusa = bhyve_vmrun_vm_chiusa(&vm);
		a_entrato = 1;				/* VM_RUN */
		usleep(1000);
		USCITO(&vm);
	} else {
		pthread_barrier_wait(&b1);
		pthread_barrier_wait(&b2);
	}
	return NULL;
}

static void *thr_b(void *x)
{
	(void)x;
	pthread_barrier_wait(&b1);
	bhyve_vmrun_vm_chiudi(&vm, EFAULT, 1);
	b_vede_in_volo = bhyve_vmrun_in_volo(&vm);
	pthread_barrier_wait(&b2);
	return NULL;
}

/* stress */
#define NV 8
static volatile int quiete, fine;
static int ingressi_dopo_quiete, ingressi_porta_chiusa, totali, snapshot;
static pthread_mutex_t mx = PTHREAD_MUTEX_INITIALIZER;

static void *vcpu_stress(void *x)
{
	BhyveVmrunPorta p;
	(void)x;
	memset(&p, 0, sizeof(p));
	while (!fine) {
		if (!AMMETTI(&p, &vm)) {
			usleep(50);
			continue;
		}
		int q = quiete, c = bhyve_vmrun_vm_chiusa(&vm);
		pthread_mutex_lock(&mx);
		totali++;
		ingressi_dopo_quiete += q;
		ingressi_porta_chiusa += c;
		pthread_mutex_unlock(&mx);
		for (volatile int i = 0; i < 200; i++)
			;				/* VM_RUN */
		USCITO(&vm);
	}
	return NULL;
}

int main(void)
{
	pthread_t a, b, t[NV];

	/* Q8a: A/B/A */
	memset(&vm, 0, sizeof(vm));
	pthread_barrier_init(&b1, NULL, 2);
	pthread_barrier_init(&b2, NULL, 2);
	pthread_create(&a, NULL, thr_a, NULL);
	pthread_create(&b, NULL, thr_b, NULL);
	pthread_join(a, NULL);
	pthread_join(b, NULL);
	VERO(a_entrato && a_vedeva_chiusa, "Q8a A entra dopo la chiusura (ammesso prima)");
	VERO(b_vede_in_volo == 1, "Q8a chi chiude vede A in volo: in_volo letto %d (0 = ingresso invisibile alla chiusura)", b_vede_in_volo);
	VERO(bhyve_vmrun_in_volo(&vm) == 0, "Q8a drain: in_volo %d dopo il ritorno di A", bhyve_vmrun_in_volo(&vm));
	{
		BhyveVmrunPorta p;
		memset(&p, 0, sizeof(p));
		VERO(!AMMETTI(&p, &vm), "Q8a dopo la chiusura A non e' piu' ammesso");
	}
	/* Q8b: B/A */
	{
		BhyveVmrunPorta p;
		memset(&vm, 0, sizeof(vm));
		memset(&p, 0, sizeof(p));
		bhyve_vmrun_vm_chiudi(&vm, EIO, 0);
		VERO(!AMMETTI(&p, &vm) && bhyve_vmrun_in_volo(&vm) == 0, "Q8b chiusa prima: rifiutato, in_volo %d", bhyve_vmrun_in_volo(&vm));
	}
	/* Q8c: stress, 20 ripetizioni */
	for (int r = 0; r < 20; r++) {
		memset(&vm, 0, sizeof(vm));
		quiete = fine = 0;
		ingressi_dopo_quiete = ingressi_porta_chiusa = totali = 0;
		for (int i = 0; i < NV; i++)
			pthread_create(&t[i], NULL, vcpu_stress, NULL);
		usleep(2000 + r * 300);
		bhyve_vmrun_vm_chiudi(&vm, EFAULT, 3);
		snapshot = bhyve_vmrun_in_volo(&vm);
		while (bhyve_vmrun_in_volo(&vm) != 0)
			;				/* drain */
		quiete = 1;
		usleep(3000);				/* i vCPU continuano a provare: nessuno deve entrare */
		fine = 1;
		for (int i = 0; i < NV; i++)
			pthread_join(t[i], NULL);
		VERO(ingressi_dopo_quiete == 0, "Q8c rip %d: %d ingressi dopo la quiescenza", r, ingressi_dopo_quiete);
		VERO(ingressi_porta_chiusa <= snapshot, "Q8c rip %d: %d ingressi con la porta chiusa, in volo alla chiusura %d",
		    r, ingressi_porta_chiusa, snapshot);
		VERO(totali > 0, "Q8c rip %d: nessun ingresso prima della chiusura", r);
	}
	printf("banco-q8: %d ok, %d errati\n", nok, nf);
	return (nf != 0);
}
