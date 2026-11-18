/*
 * msix-leggi: legge IN SOLA LETTURA la tabella MSI-X e il PBA FISICI di un
 * dispositivo PCI (parere Opus WSL2-FreeBSD 004 §2.3). Mappa la BAR con
 * PCIOCBARMMAP senza PCIIO_BAR_MMAP_RW, da /dev/pci (aperto RDWR: lo vuole la ioctl; la mappa e' VM_PROT_READ).
 * Uso: msix-leggi <bus> <slot> <func> <bar> <off tabella> <n voci> <off PBA>
 */
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/pciio.h>
#include <dev/pci/pcireg.h>
#include <vm/vm.h>
#include <err.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int
main(int argc, char **argv)
{
	struct pci_bar_mmap pbm;
	volatile uint32_t *t;
	volatile uint64_t *pba;
	unsigned long toff, poff;
	int fd, i, n;

	if (argc != 8)
		errx(2, "uso: msix-leggi <bus> <slot> <func> <bar> <off tabella> <n> <off PBA>");
	if ((fd = open("/dev/pci", O_RDWR)) < 0)	/* le ioctl oltre GETCONF vogliono FWRITE; la mappa resta READ */
		err(1, "/dev/pci");
	memset(&pbm, 0, sizeof(pbm));
	pbm.pbm_sel.pc_bus = atoi(argv[1]);
	pbm.pbm_sel.pc_dev = atoi(argv[2]);
	pbm.pbm_sel.pc_func = atoi(argv[3]);
	pbm.pbm_reg = PCIR_BAR(atoi(argv[4]));
	pbm.pbm_flags = 0;			/* sola lettura */
	pbm.pbm_memattr = VM_MEMATTR_UNCACHEABLE;
	toff = strtoul(argv[5], NULL, 0);
	n = atoi(argv[6]);
	poff = strtoul(argv[7], NULL, 0);
	if (ioctl(fd, PCIOCBARMMAP, &pbm) != 0)
		err(1, "PCIOCBARMMAP");
	t = (volatile uint32_t *)((char *)pbm.pbm_map_base + pbm.pbm_bar_off + toff);
	pba = (volatile uint64_t *)((char *)pbm.pbm_map_base + pbm.pbm_bar_off + poff);
	for (i = 0; i < n; i++)
		printf("voce %d: addr=%08x%08x data=%08x ctl=%08x%s\n", i,
		    t[i * 4 + 1], t[i * 4], t[i * 4 + 2], t[i * 4 + 3],
		    (t[i * 4 + 3] & 1) ? "  MASCHERATA" : "");
	printf("PBA: %016jx\n", (uintmax_t)pba[0]);
	munmap(pbm.pbm_map_base, pbm.pbm_map_length);
	return (0);
}
