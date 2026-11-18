/*
 * congela-tutti: parere Opus WSL2-FreeBSD 006 §1.3, esperimento 2. Chiama in
 * ciclo VM_MAP_PPTDEV_MMIO / VM_UNMAP_PPTDEV_MMIO (VMMDEV_IOCTL_LOCK_ALL_VCPUS:
 * congelano TUTTI i vCPU) per un dispositivo ppt gia' assegnato alla VM, su un
 * GPA LIBERO (mai la BAR vista dall'ospite): la mappa vista da bhyve e
 * dall'ospite non cambia. vm_open non distrugge la VM.
 * Uso: congela-tutti <vm> <b> <s> <f> <gpa> <len> <hpa> <hz> <secondi>
 */
#include <sys/types.h>
#include <machine/vmm.h>
#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <vmmapi.h>

int
main(int argc, char **argv)
{
	struct vmctx *ctx;
	uint64_t gpa, len, hpa;
	int b, s, f, hz, sec, n = 0, e1 = 0, e2 = 0;
	time_t fine;

	if (argc != 10)
		errx(2, "uso: congela-tutti <vm> <b> <s> <f> <gpa> <len> <hpa> <hz> <secondi>");
	b = atoi(argv[2]); s = atoi(argv[3]); f = atoi(argv[4]);
	gpa = strtoull(argv[5], NULL, 0); len = strtoull(argv[6], NULL, 0);
	hpa = strtoull(argv[7], NULL, 0); hz = atoi(argv[8]); sec = atoi(argv[9]);
	if ((ctx = vm_open(argv[1])) == NULL)
		err(1, "vm_open %s", argv[1]);
	fine = time(NULL) + sec;
	while (time(NULL) < fine) {
		if (vm_map_pptdev_mmio(ctx, b, s, f, gpa, len, hpa) != 0)
			e1++;
		if (vm_unmap_pptdev_mmio(ctx, b, s, f, gpa, len) != 0)
			e2++;
		n++;
		if (n == 1 && (e1 || e2))
			warn("prima coppia: map %s, unmap %s", e1 ? "FALLITA" : "ok",
			    e2 ? "FALLITA" : "ok");
		usleep(1000000 / (hz > 0 ? hz : 1));
	}
	printf("coppie map/unmap: %d (map fallite %d, unmap fallite %d)\n", n, e1, e2);
	return (0);
}
