/* cammina-ept.c -- claude 16/11/2026 (diagnosi 057 par. 3.2b): percorre un EPT a 4 livelli tenuto nella memoria di una VM
 * bhyve (l'EPT12 che Hyper-V scrive in L1), per una GPA di L2, leggendo la memoria del guest con mmap su /dev/vmm/<vm>
 * (offset = GPA di L1), in SOLA LETTURA. Uso: cammina-ept <vm> <eptp12> <gpa-l2>. Stampa R W X, tipo, PS, A, D. */
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
int main(int argc, char **argv)
{
	char nome[128];
	uint64_t eptp, gpa, t, e;
	static const char *liv[] = { "PML4", "PDPT", "PD", "PT" };
	int i, idx;
	if (argc != 4) { fprintf(stderr, "uso: %s <vm> <eptp12> <gpa-l2>\n", argv[0]); return 4; }
	snprintf(nome, sizeof(nome), "/dev/vmm/%s", argv[1]);
	if ((fd = open(nome, O_RDONLY)) < 0) { perror(nome); return 1; }
	eptp = strtoull(argv[2], NULL, 0); gpa = strtoull(argv[3], NULL, 0);
	printf("GPA L2 %#jx, EPTP12 %#jx (A/D nell'EPTP: %d)\n", (uintmax_t)gpa, (uintmax_t)eptp, (int)(eptp >> 6 & 1));
	t = eptp & 0x000ffffffffff000ULL;
	for (i = 0; i < 4; i++) {
		idx = (gpa >> (39 - 9 * i)) & 511;
		e = leggi(t + idx * 8);
		printf("%-5s [%3d] a GPA-L1 %#012jx = %#018jx  R=%d W=%d X=%d tipo=%d PS=%d A=%d D=%d -> %#jx\n", liv[i], idx,
		    (uintmax_t)(t + idx * 8), (uintmax_t)e, (int)(e & 1), (int)(e >> 1 & 1), (int)(e >> 2 & 1), (int)(e >> 3 & 7),
		    (int)(e >> 7 & 1), (int)(e >> 8 & 1), (int)(e >> 9 & 1), (uintmax_t)(e & 0x000ffffffffff000ULL));
		if (!(e & 7)) { printf("  non presente\n"); return 0; }
		if (i > 0 && i < 3 && (e >> 7 & 1)) { printf("  pagina grande\n"); return 0; }
		t = e & 0x000ffffffffff000ULL;
	}
	printf("frame in L1 (GPA-L1) della pagina: %#jx\n", (uintmax_t)t);
	return 0;
}
