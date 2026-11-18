/*
 * ept12-leggi: percorre IN SOLA LETTURA l'EPT di un L1 (Hyper-V) dentro la
 * memoria della VM bhyve indicata, per un GPA dell'L2. Nessuna creazione o
 * distruzione di VM: solo open(O_RDONLY) + mmap(PROT_READ) di /dev/vmm/<vm>.
 * Uso: ept12-leggi <vm> <eptp12 esadecimale> <l2gpa esadecimale>
 */
#include <sys/types.h>
#include <sys/mman.h>
#include <err.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

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

int
main(int argc, char **argv)
{
	char dev[64];
	uint64_t eptp, gpa, t, e;
	int lvl;
	static const char *nome[] = { "PT", "PD", "PDPT", "PML4" };

	if (argc != 4)
		errx(2, "uso: ept12-leggi <vm> <eptp12> <l2gpa>");
	snprintf(dev, sizeof(dev), "/dev/vmm/%s", argv[1]);
	eptp = strtoull(argv[2], NULL, 16);
	gpa = strtoull(argv[3], NULL, 16);
	if ((fd = open(dev, O_RDONLY)) < 0)
		err(1, "%s", dev);
	t = eptp & 0x000ffffffffff000ULL;
	for (lvl = 3; lvl >= 0; lvl--) {
		e = leggi64(t + 8 * ((gpa >> (12 + 9 * lvl)) & 0x1ff));
		printf("%-4s tabella=%#jx indice=%3ju voce=%#018jx R=%d W=%d X=%d%s\n",
		    nome[lvl], (uintmax_t)t,
		    (uintmax_t)((gpa >> (12 + 9 * lvl)) & 0x1ff), (uintmax_t)e,
		    (int)(e & 1), (int)((e >> 1) & 1), (int)((e >> 2) & 1),
		    (lvl > 0 && (e & 0x80)) ? " PAGINA GRANDE" : "");
		if ((e & 7) == 0) {
			printf("-> NON MAPPATO al livello %s\n", nome[lvl]);
			return (0);
		}
		if (lvl > 0 && (e & 0x80)) {
			uint64_t m = (1ULL << (12 + 9 * lvl)) - 1;
			printf("-> l1gpa=%#jx\n", (uintmax_t)((e & 0x000ffffffffff000ULL & ~m) | (gpa & m)));
			return (0);
		}
		t = e & 0x000ffffffffff000ULL;
	}
	printf("-> l1gpa=%#jx\n", (uintmax_t)(t | (gpa & 0xfff)));
	return (0);
}
