/*
 * ept12-sorveglia: rilegge IN SOLA LETTURA, ogni <us> microsecondi, le 4 voci
 * dell'EPT di un L1 che traducono un GPA dell'L2, e stampa (ora al
 * microsecondo) ogni cambiamento. Solo open(O_RDONLY) + mmap(PROT_READ).
 * Uso: ept12-sorveglia <vm> <eptp12> <l2gpa> <us>
 */
#include <sys/types.h>
#include <sys/mman.h>
#include <err.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static int fd;

static int
leggi64(uint64_t gpa, uint64_t *v)
{
	void *p;
	uint64_t pg = gpa & ~0xfffULL;

	p = mmap(NULL, 4096, PROT_READ, MAP_SHARED, fd, (off_t)pg);
	if (p == MAP_FAILED)
		return (-1);
	*v = *(volatile uint64_t *)((char *)p + (gpa & 0xff8));
	munmap(p, 4096);
	return (0);
}

int
main(int argc, char **argv)
{
	char dev[64], ora[32];
	uint64_t eptp, gpa, t, e[4], prec[4];
	int lvl, n, primo = 1, us;
	struct timespec ts;
	struct tm tm;

	if (argc != 5)
		errx(2, "uso: ept12-sorveglia <vm> <eptp12> <l2gpa> <us>");
	snprintf(dev, sizeof(dev), "/dev/vmm/%s", argv[1]);
	eptp = strtoull(argv[2], NULL, 16);
	gpa = strtoull(argv[3], NULL, 16);
	us = atoi(argv[4]);
	if ((fd = open(dev, O_RDONLY)) < 0)
		err(1, "%s", dev);
	setvbuf(stdout, NULL, _IOLBF, 0);
	memset(prec, 0, sizeof(prec));
	for (;;) {
		memset(e, 0, sizeof(e));
		t = eptp & 0x000ffffffffff000ULL;
		n = 0;
		for (lvl = 3; lvl >= 0; lvl--) {
			if (leggi64(t + 8 * ((gpa >> (12 + 9 * lvl)) & 0x1ff),
			    &e[lvl]) != 0)
				err(1, "mmap %#jx", (uintmax_t)t);
			n++;
			if ((e[lvl] & 7) == 0 || (lvl > 0 && (e[lvl] & 0x80)))
				break;
			t = e[lvl] & 0x000ffffffffff000ULL;
		}
		if (primo || memcmp(e, prec, sizeof(e)) != 0) {
			clock_gettime(CLOCK_REALTIME, &ts);
			localtime_r(&ts.tv_sec, &tm);
			strftime(ora, sizeof(ora), "%H:%M:%S", &tm);
			printf("%s.%06ld PML4=%#jx PDPT=%#jx PD=%#jx PT=%#jx%s\n",
			    ora, ts.tv_nsec / 1000, (uintmax_t)e[3],
			    (uintmax_t)e[2], (uintmax_t)e[1], (uintmax_t)e[0],
			    (e[lvl < 0 ? 0 : lvl] & 7) == 0 ? "  <-- NON PRESENTE" : "");
			memcpy(prec, e, sizeof(e));
			primo = 0;
		}
		usleep(us);
	}
}
