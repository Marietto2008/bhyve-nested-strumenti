/*
 * l2-pagine-leggi: percorre IN SOLA LETTURA le tabelle delle pagine di un L2
 * (x86-64 a 4 livelli) come le percorre in software l'L1 (Hyper-V): ogni
 * tabella dell'L2 (L2-GPA) tradotta con l'EPT12 in un L1-GPA, e la voce letta
 * dalla memoria dell'L1. Stessa tecnica di ept12-leggi: solo open(O_RDONLY) +
 * mmap(PROT_READ) di /dev/vmm/<vm>, nessuna creazione o distruzione di VM.
 * Serve al panic LAPIC di FreeBSD in WSL2 (rapporto 003): l'emulatore di
 * Hyper-V inietta #PF 0x10/0x11 sul fetch dell'istruzione MMIO.
 * Uso: l2-pagine-leggi <vm> <eptp12> <cr3> <gla>   (esadecimali)
 * Stampa per livello: L2-GPA della tabella, L1-GPA, voce e bit P RW US PS NX.
 */
#include <sys/types.h>
#include <sys/mman.h>
#include <err.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define	ADDR(e)	((e) & 0x000ffffffffff000ULL)

static int fd;

static uint64_t
leggi64(uint64_t gpa)
{
	void *p;
	uint64_t v, pg = gpa & ~0xfffULL;

	p = mmap(NULL, 4096, PROT_READ, MAP_SHARED, fd, (off_t)pg);
	if (p == MAP_FAILED)
		err(1, "mmap gpa %#jx", (uintmax_t)pg);
	v = *(volatile uint64_t *)((char *)p + (gpa & 0xff8));
	munmap(p, 4096);
	return (v);
}

/* L2-GPA -> L1-GPA con l'EPT12; 0 e *ok = 0 se non mappato */
static uint64_t
ept12(uint64_t eptp, uint64_t gpa, int *ok)
{
	uint64_t t = ADDR(eptp), e, m;
	int lvl;

	*ok = 0;
	for (lvl = 3; lvl >= 0; lvl--) {
		e = leggi64(t + 8 * ((gpa >> (12 + 9 * lvl)) & 0x1ff));
		if ((e & 7) == 0)
			return (0);
		if (lvl > 0 && (e & 0x80)) {
			m = (1ULL << (12 + 9 * lvl)) - 1;
			*ok = 1;
			return ((ADDR(e) & ~m) | (gpa & m));
		}
		t = ADDR(e);
	}
	*ok = 1;
	return (t | (gpa & 0xfff));
}

int
main(int argc, char **argv)
{
	char dev[64];
	uint64_t eptp, cr3, gla, t, l1, e, m;
	int lvl, ok, idx;
	static const char *nome[] = { "PT", "PD", "PDPT", "PML4" };

	if (argc != 5)
		errx(2, "uso: l2-pagine-leggi <vm> <eptp12> <cr3> <gla>");
	snprintf(dev, sizeof(dev), "/dev/vmm/%s", argv[1]);
	eptp = strtoull(argv[2], NULL, 16);
	cr3 = strtoull(argv[3], NULL, 16);
	gla = strtoull(argv[4], NULL, 16);
	if ((fd = open(dev, O_RDONLY)) < 0)
		err(1, "%s", dev);
	t = ADDR(cr3);
	for (lvl = 3; lvl >= 0; lvl--) {
		idx = (int)((gla >> (12 + 9 * lvl)) & 0x1ff);
		l1 = ept12(eptp, t, &ok);
		if (!ok) {
			printf("%-4s l2gpa=%#jx: tabella NON mappata nell'EPT12\n",
			    nome[lvl], (uintmax_t)t);
			return (1);
		}
		e = leggi64(l1 + 8 * idx);
		printf("%-4s l2gpa=%#jx l1gpa=%#jx idx=%3d voce=%#018jx P=%d RW=%d "
		    "US=%d PS=%d NX=%d\n", nome[lvl], (uintmax_t)t,
		    (uintmax_t)(l1 & ~0xfffULL), idx, (uintmax_t)e, (int)(e & 1),
		    (int)((e >> 1) & 1), (int)((e >> 2) & 1),
		    (int)(lvl > 0 && lvl < 3 && (e & 0x80) != 0), (int)(e >> 63));
		if ((e & 1) == 0)
			return (0);
		if (lvl > 0 && lvl < 3 && (e & 0x80)) {
			m = (1ULL << (12 + 9 * lvl)) - 1;
			t = (ADDR(e) & ~m) | (gla & m);
			break;
		}
		t = ADDR(e);
		if (lvl == 0)
			t |= gla & 0xfff;
	}
	l1 = ept12(eptp, t, &ok);
	printf("PAG  l2gpa=%#jx -> l1gpa=%#jx%s\n", (uintmax_t)t, (uintmax_t)l1,
	    ok ? "" : " (NON mappata nell'EPT12)");
	return (0);
}
