/*
 * Claude 23/10/2026 -- parere #35 §4: i buchi di gapmon e il limite CFS del cgroup
 * utente di WSL2 (cpu.max=199000 100000).
 *
 * Osservatore FUORI dal cgroup limitato (lo script lo sposta nel cgroup radice prima
 * di lanciarlo), per non essere frenato insieme al gruppo che osserva. Ogni 20 ms
 * legge, con pread su descrittori tenuti aperti:
 *  - /proc/<pid>/task/<tid>/schedstat del campionatore di gapmon (tempo in CPU,
 *    attesa in runqueue, volte);
 *  - cpu.stat di ogni cgroup della catena (usage_usec, user_usec, system_usec,
 *    nr_periods, nr_throttled, throttled_usec) e, se esiste, cpu.stat.local
 *    (throttled_usec);
 *  - le righe cpuN di /proc/stat (user nice system idle iowait irq softirq steal),
 *    per vedere se, durante un buco, le CPU erano in utente o nel kernel.
 * I campioni restano in memoria e vengono scritti alla fine: niente I/O su disco
 * durante la prova. Una riga per campione, colonne descritte dall'intestazione.
 *
 * uso: cgmon <secondi> <tid campionatore> <uscita> <dir cgroup>...
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define	PERIOD_NS	20000000LL
#define	MAXCG		8
#define	MAXCPU		16

static int64_t
ns(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return ((int64_t)t.tv_sec * 1000000000LL + t.tv_nsec);
}

static int
rd(int fd, char *b, size_t len)
{
	ssize_t n;

	if (fd < 0) {
		b[0] = 0;
		return (-1);
	}
	n = pread(fd, b, len - 1, 0);
	if (n < 0)
		n = 0;
	b[n] = 0;
	return ((int)n);
}

/* valore della chiave "k" in un file chiave/valore di cgroup, -1 se assente */
static long long
kv(const char *b, const char *k)
{
	size_t l = strlen(k);
	const char *p = b;

	while ((p = strstr(p, k)) != NULL) {
		if ((p == b || p[-1] == '\n') && p[l] == ' ')
			return (atoll(p + l + 1));
		p += l;
	}
	return (-1);
}

int
main(int argc, char **argv)
{
	static const char *keys[] = { "usage_usec", "user_usec", "system_usec",
	    "nr_periods", "nr_throttled", "throttled_usec" };
	int fs, fst, fcg[MAXCG], fcl[MAXCG], ncg, ncpu = 0, i, k;
	char path[512], b[8192], *buf, *w, *e;
	int64_t dur, t0, next, t;
	size_t cap;

	if (argc < 5) {
		fprintf(stderr, "uso: cgmon <secondi> <tid> <uscita> <cgroup>...\n");
		return (1);
	}
	dur = atoll(argv[1]) * 1000000000LL;
	snprintf(path, sizeof(path), "/proc/%s/task/%s/schedstat", argv[2], argv[2]);
	fs = open(path, O_RDONLY);
	fst = open("/proc/stat", O_RDONLY);
	ncg = argc - 4 > MAXCG ? MAXCG : argc - 4;
	for (i = 0; i < ncg; i++) {
		snprintf(path, sizeof(path), "%s/cpu.stat", argv[4 + i]);
		fcg[i] = open(path, O_RDONLY);
		snprintf(path, sizeof(path), "%s/cpu.stat.local", argv[4 + i]);
		fcl[i] = open(path, O_RDONLY);
	}
	rd(fst, b, sizeof(b));
	for (w = b; (w = strstr(w, "\ncpu")) != NULL; w++)
		if (w[4] >= '0' && w[4] <= '9')
			ncpu++;
	if (ncpu > MAXCPU)
		ncpu = MAXCPU;
	cap = (size_t)(dur / PERIOD_NS + 100) * (size_t)(64 + ncg * 140 + ncpu * 110);
	buf = malloc(cap);
	if (buf == NULL)
		return (1);
	w = buf;
	e = buf + cap;
	w += snprintf(w, e - w, "# cgmon tid=%s schedstat=%s\n# colonne: mono_ns "
	    "run_ns wait_ns volte", argv[2], fs >= 0 ? "si" : "NO");
	for (i = 0; i < ncg; i++)
		w += snprintf(w, e - w, " | cg%d(%s): usage user system periods "
		    "throttled throttled_usec local_throttled_usec%s", i, argv[4 + i],
		    fcg[i] >= 0 ? "" : " [cpu.stat NON leggibile]");
	for (i = 0; i < ncpu; i++)
		w += snprintf(w, e - w, " | cpu%d: user nice system idle iowait irq "
		    "softirq steal (jiffies)", i);
	w += snprintf(w, e - w, "\n");
	t0 = next = ns();
	for (;;) {
		t = ns();
		if (e - w < 64 + ncg * 140 + ncpu * 110)
			break;
		rd(fs, b, sizeof(b));
		w += snprintf(w, e - w, "%lld %s", (long long)t, b[0] ? b : "-1 -1 -1");
		while (w > buf && w[-1] == '\n')
			*--w = 0;
		for (i = 0; i < ncg; i++) {
			rd(fcg[i], b, sizeof(b));
			w += snprintf(w, e - w, " |");
			for (k = 0; k < 6; k++)
				w += snprintf(w, e - w, " %lld", kv(b, keys[k]));
			if (rd(fcl[i], b, sizeof(b)) >= 0)
				w += snprintf(w, e - w, " %lld", kv(b, "throttled_usec"));
			else
				w += snprintf(w, e - w, " -1");
		}
		rd(fst, b, sizeof(b));
		for (i = 0; i < ncpu; i++) {
			char tag[16], *p;
			unsigned long long v[8] = { 0 };

			snprintf(tag, sizeof(tag), "\ncpu%d ", i);
			p = strstr(b, tag);
			if (p != NULL)
				sscanf(p + strlen(tag), "%llu %llu %llu %llu %llu %llu "
				    "%llu %llu", &v[0], &v[1], &v[2], &v[3], &v[4],
				    &v[5], &v[6], &v[7]);
			w += snprintf(w, e - w, " | %llu %llu %llu %llu %llu %llu "
			    "%llu %llu", v[0], v[1], v[2], v[3], v[4], v[5], v[6],
			    v[7]);
		}
		w += snprintf(w, e - w, "\n");
		if (t - t0 >= dur)
			break;
		/* passo fisso sul monotono: un ritardo dell'osservatore si vede nei tempi */
		next += PERIOD_NS;
		if (next < t)
			next = t + PERIOD_NS;
		{
			struct timespec ts = { next / 1000000000LL,
			    next % 1000000000LL };

			clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL);
		}
	}
	{
		FILE *f = fopen(argv[3], "w");

		if (f == NULL)
			return (1);
		fwrite(buf, 1, w - buf, f);
		fclose(f);
	}
	return (0);
}
