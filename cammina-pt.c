/* cammina-pt.c -- claude 15/11/2026 (prova A): percorre le tabelle delle pagine a 4 livelli del guest di una VM bhyve
 * per un indirizzo virtuale, leggendo la memoria fisica del guest con mmap su /dev/vmm/<vm> (offset = GPA), in SOLA
 * LETTURA. Uso: cammina-pt <vm> <cr3> <va>. Stampa ogni voce con P, RW, US, PS, A, D, NX. */
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
static int fd;
static uint64_t leggi(uint64_t gpa)
{
	uint64_t base = gpa & ~0xfffULL, v;
	void *p = mmap(NULL, 4096, PROT_READ, MAP_SHARED, fd, base);
	if (p == MAP_FAILED) { printf("  mmap del GPA %#jx fallito\n", (uintmax_t)base); exit(1); }
	v = *(uint64_t *)((char *)p + (gpa & 0xfff));
	munmap(p, 4096);
	return v;
}
static void stampa(const char *liv, int idx, uint64_t gpa, uint64_t e)
{
	printf("%-5s [%3d] a GPA %#012jx = %#018jx  P=%d RW=%d US=%d PS=%d A=%d D=%d NX=%d  -> %#jx\n", liv, idx,
	    (uintmax_t)gpa, (uintmax_t)e, (int)(e & 1), (int)(e >> 1 & 1), (int)(e >> 2 & 1), (int)(e >> 7 & 1),
	    (int)(e >> 5 & 1), (int)(e >> 6 & 1), (int)(e >> 63), (uintmax_t)(e & 0x000ffffffffff000ULL));
}
int main(int argc, char **argv)
{
	char nome[128];
	uint64_t cr3, va, t, e;
	static const char *liv[] = { "PML4", "PDPT", "PD", "PT" };
	int i, idx;
	if (argc != 4) { fprintf(stderr, "uso: %s <vm> <cr3> <va>\n", argv[0]); return 4; }
	snprintf(nome, sizeof(nome), "/dev/vmm/%s", argv[1]);
	if ((fd = open(nome, O_RDONLY)) < 0) { perror(nome); return 1; }
	cr3 = strtoull(argv[2], NULL, 0); va = strtoull(argv[3], NULL, 0);
	t = cr3 & 0x000ffffffffff000ULL;
	printf("VA %#jx, CR3 %#jx\n", (uintmax_t)va, (uintmax_t)cr3);
	for (i = 0; i < 4; i++) {
		idx = (va >> (39 - 9 * i)) & 511;
		e = leggi(t + idx * 8);
		stampa(liv[i], idx, t + idx * 8, e);
		if (!(e & 1)) { printf("  non presente\n"); return 0; }
		if (i > 0 && i < 3 && (e >> 7 & 1)) { printf("  pagina grande\n"); return 0; }
		t = e & 0x000ffffffffff000ULL;
	}
	return 0;
}
