/*
 * claude-lag.c -- Claude 04/11/2026. Misura i blocchi di FreeBSD nella VM di WSL: un thread fissato su ogni CPU
 * dorme 2 ms in ciclo e controlla quanto tempo e' passato davvero (CLOCK_MONOTONIC, che in Hyper-V viene dal TSC di
 * riferimento e continua a correre anche se il vCPU e' fermo). Un buco oltre la soglia vuol dire che quel vCPU non ha
 * eseguito niente per quel tempo. Se il buco c'e' su tutte le CPU insieme, e' ferma tutta la VM.
 * Uso: claude-lag <secondi> [soglia ms, 100]. Una riga per buco: ora (UTC, al ms), CPU, durata; ogni 60 s un riepilogo.
 */
#include <sys/param.h>
#include <sys/cpuset.h>
#include <sys/sysctl.h>
#include <err.h>
#include <pthread.h>
#include <pthread_np.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

static int durata, soglia_ms;
static _Atomic long buchi, peggiore_us;

static void
ora(char *buf, size_t len)
{
	struct timespec ts;
	struct tm tm;

	clock_gettime(CLOCK_REALTIME, &ts);
	gmtime_r(&ts.tv_sec, &tm);
	snprintf(buf, len, "%02d:%02d:%02d.%03ld", tm.tm_hour, tm.tm_min, tm.tm_sec, ts.tv_nsec / 1000000);
}

static void *
sonda(void *arg)
{
	int cpu = (int)(intptr_t)arg;
	struct timespec prima, dopo, pausa = { 0, 2000000 }, fine;
	cpuset_t set;
	char t[32];
	long us, max;

	CPU_ZERO(&set);
	CPU_SET(cpu, &set);
	if (pthread_setaffinity_np(pthread_self(), sizeof(set), &set) != 0)
		warnx("cpu%d: affinita' non impostata", cpu);
	clock_gettime(CLOCK_MONOTONIC, &fine);
	fine.tv_sec += durata;
	for (;;) {
		clock_gettime(CLOCK_MONOTONIC, &prima);
		if (prima.tv_sec > fine.tv_sec)
			break;
		nanosleep(&pausa, NULL);
		clock_gettime(CLOCK_MONOTONIC, &dopo);
		us = (dopo.tv_sec - prima.tv_sec) * 1000000L + (dopo.tv_nsec - prima.tv_nsec) / 1000;
		if (us >= soglia_ms * 1000L) {
			ora(t, sizeof(t));
			printf("%s UTC cpu%d buco %ld ms\n", t, cpu, us / 1000);
			fflush(stdout);
			atomic_fetch_add(&buchi, 1);
			max = atomic_load(&peggiore_us);
			while (us > max && !atomic_compare_exchange_weak(&peggiore_us, &max, us))
				;
		}
	}
	return (NULL);
}

int
main(int argc, char **argv)
{
	pthread_t *th;
	char t[32];
	size_t len;
	int ncpu, i, s;

	if (argc < 2)
		errx(2, "uso: claude-lag <secondi> [soglia ms]");
	durata = atoi(argv[1]);
	soglia_ms = argc > 2 ? atoi(argv[2]) : 100;
	len = sizeof(ncpu);
	if (sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0) != 0)
		err(1, "hw.ncpu");
	setvbuf(stdout, NULL, _IOLBF, 0);
	ora(t, sizeof(t));
	printf("%s UTC claude-lag: %d CPU, %d s, soglia %d ms\n", t, ncpu, durata, soglia_ms);
	th = calloc(ncpu, sizeof(*th));
	for (i = 0; i < ncpu; i++)
		if (pthread_create(&th[i], NULL, sonda, (void *)(intptr_t)i) != 0)
			err(1, "pthread_create");
	for (s = 60; s <= durata; s += 60) {
		sleep(60);
		ora(t, sizeof(t));
		printf("%s UTC riepilogo: %ld buchi finora, il peggiore %ld ms\n", t, atomic_load(&buchi),
		    atomic_load(&peggiore_us) / 1000);
	}
	for (i = 0; i < ncpu; i++)
		pthread_join(th[i], NULL);
	ora(t, sizeof(t));
	printf("%s UTC fine: %ld buchi, il peggiore %ld ms\n", t, atomic_load(&buchi), atomic_load(&peggiore_us) / 1000);
	return (0);
}
