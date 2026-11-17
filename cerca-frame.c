/* cerca-frame.c -- claude 16/11/2026 (diagnosi 057 par. 3.1): cerca in tutta la memoria di una VM bhyve (mmap su
 * /dev/vmm/<vm>, offset = GPA, SOLA LETTURA, blocchi da 2 MB, buchi saltati) le pagine che contengono i tre puntatori
 * ai callout persi: 0xfffff800164c84a8 a 0x940, 0xfffff800f68144a8 a 0xa08, 0xfffff800164a54a8 a 0xd28.
 * Uso: cerca-frame <vm> <GB massimi>. Stampa ogni pagina con almeno uno dei tre e quanti ne ha. */
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
int main(int argc, char **argv)
{
	char nome[128];
	const uint64_t blocco = 2ULL << 20;
	uint64_t max, off, pag, buchi = 0, letti = 0, trovate = 0;
	int fd;
	if (argc != 3) { fprintf(stderr, "uso: %s <vm> <GB massimi>\n", argv[0]); return 4; }
	snprintf(nome, sizeof(nome), "/dev/vmm/%s", argv[1]);
	if ((fd = open(nome, O_RDONLY)) < 0) { perror(nome); return 1; }
	max = strtoull(argv[2], NULL, 0) << 30;
	for (off = 0; off < max; off += blocco) {
		uint8_t *p = mmap(NULL, blocco, PROT_READ, MAP_SHARED, fd, off);
		if (p == MAP_FAILED) { buchi++; continue; }
		letti++;
		for (pag = 0; pag < blocco; pag += 4096) {
			uint64_t a = *(uint64_t *)(p + pag + 0x940), b = *(uint64_t *)(p + pag + 0xa08),
			    c = *(uint64_t *)(p + pag + 0xd28);
			int n = (a == 0xfffff800164c84a8ULL) + (b == 0xfffff800f68144a8ULL) + (c == 0xfffff800164a54a8ULL);
			if (n) {
				trovate++;
				printf("GPA-L1 %#012jx: %d su 3  [0x940]=%#jx [0xa08]=%#jx [0xd28]=%#jx\n", (uintmax_t)(off + pag), n,
				    (uintmax_t)a, (uintmax_t)b, (uintmax_t)c);
			}
		}
		munmap(p, blocco);
	}
	printf("blocchi da 2 MB letti %ju (%ju MB), buchi %ju, pagine con almeno un puntatore %ju\n", (uintmax_t)letti,
	    (uintmax_t)(letti * 2), (uintmax_t)buchi, (uintmax_t)trovate);
	return 0;
}
