/* cerca-valori.c -- claude 16/11/2026 (diagnosi 057 par. 3.1): cerca in tutta la memoria di una VM bhyve (mmap su
 * /dev/vmm/<vm>, offset = GPA, SOLA LETTURA, blocchi da 2 MB, buchi saltati) le pagine che contengono i valori dati
 * agli scostamenti dati. Uso: cerca-valori <vm> <GB> <scost>=<valore> [...]. Stampa le pagine con almeno uno e quanti.
 * Conta anche i byte letti davvero (somma di controllo) per escludere letture vuote. */
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
int main(int argc, char **argv)
{
	char nome[128];
	const uint64_t blocco = 2ULL << 20;
	uint64_t max, off, pag, buchi = 0, letti = 0, trovate = 0, nonzero = 0, so[8], va[8];
	int fd, n, i, k;
	if (argc < 4 || argc > 11) { fprintf(stderr, "uso: %s <vm> <GB> <scost>=<valore> ...\n", argv[0]); return 4; }
	snprintf(nome, sizeof(nome), "/dev/vmm/%s", argv[1]);
	if ((fd = open(nome, O_RDONLY)) < 0) { perror(nome); return 1; }
	max = strtoull(argv[2], NULL, 0) << 30;
	for (n = 0; n < argc - 3; n++) {
		char *uguale = strchr(argv[n + 3], '=');
		if (!uguale) { fprintf(stderr, "coppia senza '=': %s\n", argv[n + 3]); return 4; }
		so[n] = strtoull(argv[n + 3], NULL, 0); va[n] = strtoull(uguale + 1, NULL, 0);
	}
	for (off = 0; off < max; off += blocco) {
		uint8_t *p = mmap(NULL, blocco, PROT_READ, MAP_SHARED, fd, off);
		if (p == MAP_FAILED) { buchi++; continue; }
		letti++;
		for (pag = 0; pag < blocco; pag += 4096) {
			if (*(uint64_t *)(p + pag + 8) != 0) nonzero++;
			for (k = 0, i = 0; i < n; i++)
				if (*(uint64_t *)(p + pag + so[i]) == va[i]) k++;
			if (k) {
				trovate++;
				printf("GPA-L1 %#012jx: %d su %d", (uintmax_t)(off + pag), k, n);
				for (i = 0; i < n; i++) printf("  [%#jx]=%#jx", (uintmax_t)so[i], (uintmax_t)*(uint64_t *)(p + pag + so[i]));
				printf("\n");
			}
		}
		munmap(p, blocco);
	}
	printf("blocchi letti %ju (%ju MB), buchi %ju, pagine con qword +8 non nulla %ju, pagine trovate %ju\n",
	    (uintmax_t)letti, (uintmax_t)(letti * 2), (uintmax_t)buchi, (uintmax_t)nonzero, (uintmax_t)trovate);
	return 0;
}
