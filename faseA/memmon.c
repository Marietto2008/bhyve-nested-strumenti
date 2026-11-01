/*
 * Claude 24/10/2026 -- parere #42 §3: serie temporali della memoria di Linux in WSL2,
 * da confrontare con le hypercall 0x004B (MapGpaPages) della radice e con le fasi del ciclo
 * dd / drop_caches / rilettura. Ogni 100 ms una riga:
 *   M real_ns mono_ns MemFree Cached Buffers MemAvailable (kB) | pgfree pgalloc_dma32
 *     pgalloc_normal pgscan_kswapd pgscan_direct pgsteal_kswapd pgsteal_direct
 * real_ns = CLOCK_REALTIME di Linux, lo stesso orologio di gapmon e dei marcatori di gapmem.sh
 * (gapmon lo porta sull'ora dell'host con le righe SYNC). Solo letture di /proc.
 * uso: memmon <secondi> <file>
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static long long
ns(clockid_t c)
{
	struct timespec t;

	clock_gettime(c, &t);
	return ((long long)t.tv_sec * 1000000000LL + t.tv_nsec);
}

static const char *mk[] = { "MemFree:", "Cached:", "Buffers:", "MemAvailable:" };
static const char *vk[] = { "pgfree", "pgalloc_dma32", "pgalloc_normal", "pgscan_kswapd",
    "pgscan_direct", "pgsteal_kswapd", "pgsteal_direct" };
#define NM (sizeof(mk) / sizeof(mk[0]))
#define NV (sizeof(vk) / sizeof(vk[0]))

int
main(int argc, char **argv)
{
	char l[256], k[64];
	long long v, m[NM], w[NV], t0, next;
	FILE *o, *f;
	size_t i;
	int sec;

	if (argc != 3) {
		fprintf(stderr, "uso: memmon <secondi> <file>\n");
		return (1);
	}
	sec = atoi(argv[1]);
	if ((o = fopen(argv[2], "w")) == NULL) {
		perror(argv[2]);
		return (1);
	}
	fprintf(o, "# memmon %d s: M real mono MemFree Cached Buffers MemAvailable | "
	    "pgfree pgalloc_dma32 pgalloc_normal pgscan_kswapd pgscan_direct "
	    "pgsteal_kswapd pgsteal_direct\n", sec);
	t0 = ns(CLOCK_MONOTONIC);
	next = t0;
	while (ns(CLOCK_MONOTONIC) - t0 < (long long)sec * 1000000000LL) {
		memset(m, 0, sizeof(m));
		memset(w, 0, sizeof(w));
		if ((f = fopen("/proc/meminfo", "r")) != NULL) {
			while (fgets(l, sizeof(l), f) != NULL)
				for (i = 0; i < NM; i++)
					if (strncmp(l, mk[i], strlen(mk[i])) == 0)
						m[i] = atoll(l + strlen(mk[i]));
			fclose(f);
		}
		if ((f = fopen("/proc/vmstat", "r")) != NULL) {
			while (fgets(l, sizeof(l), f) != NULL)
				if (sscanf(l, "%63s %lld", k, &v) == 2)
					for (i = 0; i < NV; i++)
						if (strcmp(k, vk[i]) == 0)
							w[i] = v;
			fclose(f);
		}
		fprintf(o, "M %lld %lld", ns(CLOCK_REALTIME), ns(CLOCK_MONOTONIC));
		for (i = 0; i < NM; i++)
			fprintf(o, " %lld", m[i]);
		fprintf(o, " |");
		for (i = 0; i < NV; i++)
			fprintf(o, " %lld", w[i]);
		fprintf(o, "\n");
		fflush(o);
		next += 100000000LL;
		v = next - ns(CLOCK_MONOTONIC);
		if (v > 0) {
			struct timespec d = { v / 1000000000LL, v % 1000000000LL };
			nanosleep(&d, NULL);
		}
	}
	fclose(o);
	return (0);
}
