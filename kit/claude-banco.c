/*
 * claude-banco.c -- benchmark used at every virtualization level (host L0, VM L1, nested VM L2): same static binary,
 * same tests, same output. Comments below are in Italian; the output lines are "BANCO <test> <value> <unit>".
 *   cpu1/cpuN  integer mixing loop on one thread / on every CPU (million steps per second)
 *   syscall    getppid() cost (ns)          fork   fork + execve(/usr/bin/true) + wait (us)
 *   pipe       one-byte round trip between two threads pinned to CPUs 0 and N/2 (median, p99, max, us)
 *   timer      nanosleep(1 ms) on one thread per CPU: delay beyond 1 ms (median, p99, p99.9, max, us)
 *   pagine     first write to each 4 KB page of a 512 MB anonymous mapping (thousand pages/s)
 *   memcpy     8 copies of 256 MB (GB/s)
 * Build: cc -O2 -static -pthread -o claude-banco claude-banco.c (FreeBSD); cc -O2 -pthread on Linux.
 * Usage: claude-banco [seconds per test, 5] [comma-separated tests, all]
 */
/*
 * claude-banco.c -- Claude 18/11/2026. Banco di prova delle prestazioni, identico a ogni livello di virtualizzazione
 * (host L0, VM L1, VM annidata L2): stesso binario statico, stesse prove, stessa uscita.
 *
 * Prove (una riga "BANCO <prova> <valore> <unita'>" ciascuna):
 *   cpu1      calcolo intero su un thread (miscela di moltiplicazioni e rotazioni), milioni di passi al secondo
 *   cpuN      la stessa su tutti i thread logici visti, somma
 *   memcpy    copia fra due aree da 256 MB, GB/s (media di 8 copie)
 *   pagine    mmap anonima di 512 MB, prima scrittura di ogni pagina da 4 KB, munmap: migliaia di pagine al secondo
 *   syscall   getppid() in ciclo, ns per chiamata
 *   fork      fork + execve di /usr/bin/true + wait, microsecondi per processo
 *   pipe      andata e ritorno di un byte fra due thread fissati su CPU diverse, microsecondi (mediana e p99)
 *   timer     nanosleep da 1 ms su un thread per CPU, ritardo oltre il ms: mediana, p99, p99.9, massimo (us)
 *
 * Uso: claude-banco [secondi per prova, 5] [prove separate da virgole, tutte]
 * Compilazione: cc -O2 -static -pthread -o claude-banco claude-banco.c (FreeBSD; su Linux cc -O2 -pthread)
 */
#ifdef __linux__
#define _GNU_SOURCE
#include <sched.h>
#else
#include <sys/param.h>
#include <sys/cpuset.h>
#include <sys/sysctl.h>
#include <pthread_np.h>
#endif
#include <sys/mman.h>
#include <sys/wait.h>
#include <err.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static int secondi = 5, ncpu;

static double
adesso(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (ts.tv_sec + ts.tv_nsec / 1e9);
}

#ifdef __linux__
typedef cpu_set_t cpuset_t;
#endif
#ifndef nitems
#define nitems(x) (sizeof(x) / sizeof((x)[0]))
#endif

static void
fissa(int cpu)
{
	cpuset_t set;

	CPU_ZERO(&set);
	CPU_SET(cpu % ncpu, &set);
	pthread_setaffinity_np(pthread_self(), sizeof(set), &set);
}

static int
confronta_long(const void *a, const void *b)
{
	long x = *(const long *)a, y = *(const long *)b;

	return (x < y ? -1 : x > y);
}

/* --- cpu: un passo = 8 operazioni intere dipendenti; il risultato si stampa per non farlo eliminare */
static volatile uint64_t pozzo;

static uint64_t
calcola(double durata, uint64_t *passi)
{
	uint64_t x = 0x9e3779b97f4a7c15ULL, n = 0;
	double fine = adesso() + durata;
	int i;

	while (adesso() < fine) {
		for (i = 0; i < 100000; i++) {
			x ^= x >> 31;
			x *= 0xbf58476d1ce4e5b9ULL;
			x ^= x >> 27;
			x *= 0x94d049bb133111ebULL;
		}
		n += 100000;
	}
	*passi = n;
	return (x);
}

struct lavoro {
	int cpu;
	uint64_t passi;
};

static void *
filo_cpu(void *arg)
{
	struct lavoro *l = arg;

	fissa(l->cpu);
	pozzo += calcola(secondi, &l->passi);
	return (NULL);
}

static void
prova_cpu(void)
{
	pthread_t *t = calloc(ncpu, sizeof(*t));
	struct lavoro *l = calloc(ncpu, sizeof(*l));
	uint64_t passi, tot = 0;
	double t0;
	int i;

	t0 = adesso();
	pozzo += calcola(secondi, &passi);
	printf("BANCO cpu1 %.1f Mpassi/s\n", passi / (adesso() - t0) / 1e6);
	fflush(stdout);
	t0 = adesso();
	for (i = 0; i < ncpu; i++) {
		l[i].cpu = i;
		pthread_create(&t[i], NULL, filo_cpu, &l[i]);
	}
	for (i = 0; i < ncpu; i++) {
		pthread_join(t[i], NULL);
		tot += l[i].passi;
	}
	printf("BANCO cpuN %.1f Mpassi/s (%d thread, %.2f x cpu1)\n", tot / (adesso() - t0) / 1e6, ncpu,
	    (double)tot / passi);
	free(t);
	free(l);
}

/* la copia passa da un puntatore volatile: il compilatore non la puo' eliminare */
static void *(*volatile copia)(void *, const void *, size_t) = memcpy;

static void
prova_memcpy(void)
{
	size_t n = 256UL << 20;
	char *a = malloc(n), *b = malloc(n);
	double t0;
	int i;

	memset(a, 1, n);
	memset(b, 2, n);
	t0 = adesso();
	for (i = 0; i < 8; i++) {
		copia(i & 1 ? a : b, i & 1 ? b : a, n);
		a[(i * 4099) % n]++;	/* la copia dopo dipende da questa */
	}
	printf("BANCO memcpy %.2f GB/s\n", 8.0 * n / (adesso() - t0) / 1e9);
	pozzo += a[n / 2] + b[n / 3];
	free(a);
	free(b);
}

static void
prova_pagine(void)
{
	size_t n = 512UL << 20, p;
	long pagine = 0;
	double t0 = adesso(), fine = t0 + secondi;
	char *m;

	while (adesso() < fine) {
		m = mmap(NULL, n, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
		if (m == MAP_FAILED)
			err(1, "mmap");
		for (p = 0; p < n; p += 4096)
			m[p] = 1;
		munmap(m, n);
		pagine += n / 4096;
	}
	printf("BANCO pagine %.1f kpagine/s\n", pagine / (adesso() - t0) / 1e3);
}

static void
prova_syscall(void)
{
	long n = 0;
	double t0 = adesso(), fine = t0 + secondi;
	int i;

	while (adesso() < fine) {
		for (i = 0; i < 10000; i++)
			(void)getppid();
		n += 10000;
	}
	printf("BANCO syscall %.1f ns\n", (adesso() - t0) / n * 1e9);
}

static void
prova_fork(void)
{
	char *argv[] = { "true", NULL }, *envp[] = { NULL };
	long n = 0;
	double t0 = adesso(), fine = t0 + secondi;
	pid_t pid;
	int st;

	while (adesso() < fine) {
		pid = fork();
		if (pid == 0) {
			execve("/usr/bin/true", argv, envp);
			_exit(127);
		}
		if (pid < 0)
			err(1, "fork");
		waitpid(pid, &st, 0);
		n++;
	}
	printf("BANCO fork %.1f us\n", (adesso() - t0) / n * 1e6);
}

/* --- pipe: due thread su CPU diverse (0 e ncpu/2: su un host con HT sono core fisici diversi) */
static int ab[2], ba[2];
static long giri_pipe;

static void *
eco(void *arg)
{
	char c;
	long i;

	(void)arg;
	fissa(ncpu > 1 ? ncpu / 2 : 0);
	for (i = 0; i < giri_pipe; i++) {
		if (read(ab[0], &c, 1) != 1)
			break;
		write(ba[1], &c, 1);
	}
	return (NULL);
}

static void
prova_pipe(void)
{
	long i, n = 20000, *us;
	pthread_t t;
	double a;
	char c = 'x';

	if (pipe(ab) || pipe(ba))
		err(1, "pipe");
	giri_pipe = n;
	us = calloc(n, sizeof(*us));
	pthread_create(&t, NULL, eco, NULL);
	fissa(0);
	for (i = 0; i < n; i++) {
		a = adesso();
		write(ab[1], &c, 1);
		read(ba[0], &c, 1);
		us[i] = (long)((adesso() - a) * 1e7);	/* decimi di us */
	}
	pthread_join(t, NULL);
	qsort(us, n, sizeof(*us), confronta_long);
	printf("BANCO pipe %.1f us mediana, p99 %.1f, max %.1f\n", us[n / 2] / 10.0, us[n * 99 / 100] / 10.0,
	    us[n - 1] / 10.0);
	free(us);
}

/* --- timer: ogni thread raccoglie i ritardi oltre 1 ms delle sue pause */
struct sonda {
	int cpu;
	long n, *ritardo;
};

static void *
filo_timer(void *arg)
{
	struct sonda *s = arg;
	struct timespec pausa = { 0, 1000000 };
	double a, fine;
	long max = secondi * 1000;

	fissa(s->cpu);
	s->ritardo = calloc(max, sizeof(long));
	fine = adesso() + secondi;
	while (s->n < max && (a = adesso()) < fine) {
		nanosleep(&pausa, NULL);
		s->ritardo[s->n++] = (long)((adesso() - a) * 1e6) - 1000;
	}
	return (NULL);
}

static void
prova_timer(void)
{
	pthread_t *t = calloc(ncpu, sizeof(*t));
	struct sonda *s = calloc(ncpu, sizeof(*s));
	long tot = 0, k = 0, *tutti;
	int i, j;

	for (i = 0; i < ncpu; i++) {
		s[i].cpu = i;
		pthread_create(&t[i], NULL, filo_timer, &s[i]);
	}
	for (i = 0; i < ncpu; i++) {
		pthread_join(t[i], NULL);
		tot += s[i].n;
	}
	tutti = calloc(tot, sizeof(long));
	for (i = 0; i < ncpu; i++)
		for (j = 0; j < s[i].n; j++)
			tutti[k++] = s[i].ritardo[j];
	qsort(tutti, tot, sizeof(long), confronta_long);
	printf("BANCO timer %ld us mediana, p99 %ld, p99.9 %ld, max %ld (%ld pause su %d CPU)\n", tutti[tot / 2],
	    tutti[tot * 99 / 100], tutti[tot * 999 / 1000], tutti[tot - 1], tot, ncpu);
	free(tutti);
	for (i = 0; i < ncpu; i++)
		free(s[i].ritardo);
	free(s);
	free(t);
}

static const struct {
	const char *nome;
	void (*fn)(void);
} prove[] = {
	/* le prove di memoria in fondo: dopo, il processo resta grande e fork costerebbe di piu' */
	{ "cpu", prova_cpu }, { "syscall", prova_syscall }, { "fork", prova_fork }, { "pipe", prova_pipe },
	{ "timer", prova_timer }, { "pagine", prova_pagine }, { "memcpy", prova_memcpy },
};

int
main(int argc, char **argv)
{
	char modello[128] = "?", guest[32] = "?";
	size_t i;

	if (argc > 1)
		secondi = atoi(argv[1]);
#ifdef __linux__
	FILE *f;
	char riga[256], *c;

	ncpu = (int)sysconf(_SC_NPROCESSORS_ONLN);
	if ((f = fopen("/proc/cpuinfo", "r")) != NULL) {
		while (fgets(riga, sizeof(riga), f) != NULL)
			if (strncmp(riga, "model name", 10) == 0 && (c = strchr(riga, ':')) != NULL) {
				snprintf(modello, sizeof(modello), "%s", c + 2);
				modello[strcspn(modello, "\n")] = 0;
				break;
			}
		fclose(f);
	}
	snprintf(guest, sizeof(guest), "linux");
#else
	size_t len = sizeof(ncpu);

	if (sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0) != 0)
		ncpu = 1;
	len = sizeof(modello);
	sysctlbyname("hw.model", modello, &len, NULL, 0);
	len = sizeof(guest);
	sysctlbyname("kern.vm_guest", guest, &len, NULL, 0);
#endif
	if (ncpu < 1)
		ncpu = 1;
	printf("BANCO inizio %d CPU, vm_guest %s, %s, %d s per prova\n", ncpu, guest, modello, secondi);
	fflush(stdout);
	for (i = 0; i < nitems(prove); i++) {
		if (argc > 2 && strstr(argv[2], prove[i].nome) == NULL)
			continue;
		prove[i].fn();
		fflush(stdout);
	}
	printf("BANCO fine\n");
	return (0);
}
