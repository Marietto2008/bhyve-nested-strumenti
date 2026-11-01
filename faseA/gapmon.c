/*
 * Claude 23/10/2026 -- parere #33 §3: i buchi dell'orologio di WSL2 durante l'I/O.
 * Tre domande: il campionatore era BLOCCATO (A), PRONTO ma non schedulato (B), o
 * l'intera partizione WSL2 era ferma (C)?
 *
 *  - campionatore: ogni 10 ms CLOCK_MONOTONIC/REALTIME; un buco >= 200 ms viene
 *    stampato con inizio/fine (monotono e reale), CPU prima/dopo, delta di
 *    /proc/self/task/TID/schedstat (tempo in CPU, attesa in runqueue, volte) e
 *    delta dello steal di /proc/stat;
 *  - osservatore (secondo thread): ogni 50 ms legge stato e wchan del campionatore,
 *    /proc/pressure/{cpu,io,memory}; tiene un anello di campioni e, a ogni buco,
 *    il campionatore stampa quelli caduti dentro il buco. Un buco senza campioni
 *    dell'osservatore dice che anche lui era fermo (partizione intera, caso C).
 *  - ogni secondo, da un TERZO thread, un ping UDP all'host (tsecho.py) in stile NTP:
 *    "SYNC t1 t4 host_real" con l'RTT, per portare i tempi di Linux su quelli
 *    di FreeBSD (CLOCK_REALTIME di entrambi).
 *  - Claude 24/10/2026 (parere #38): alla fine di ogni buco, una riga "BUCO ms inizio fine"
 *    all'host da un socket separato: tsecho.py la registra con l'ora dell'host.
 *
 * uso: gapmon <secondi> <ip host> <porta>
 */
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#define	GAP_NS		200000000LL
#define	RING		512

static int64_t
ns(clockid_t c)
{
	struct timespec t;

	clock_gettime(c, &t);
	return ((int64_t)t.tv_sec * 1000000000LL + t.tv_nsec);
}

static int
slurp(const char *path, char *buf, size_t len)
{
	FILE *f = fopen(path, "r");
	size_t n;

	if (f == NULL) {
		buf[0] = 0;
		return (-1);
	}
	n = fread(buf, 1, len - 1, f);
	fclose(f);
	buf[n] = 0;
	while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == ' '))
		buf[--n] = 0;
	return (0);
}

/* steal totale (colonna 8 della riga cpu di /proc/stat), in tick */
static long long
steal(void)
{
	char b[512];
	long long v[10] = { 0 };

	if (slurp("/proc/stat", b, sizeof(b)) != 0)
		return (-1);
	sscanf(b, "cpu %lld %lld %lld %lld %lld %lld %lld %lld", &v[0], &v[1],
	    &v[2], &v[3], &v[4], &v[5], &v[6], &v[7]);
	return (v[7]);
}

struct obs {
	int64_t	mono;
	char	state;
	char	wchan[40];
	char	psi_cpu[32], psi_io[32];
};
static struct obs ring[RING];
static volatile unsigned rhead;
static volatile pid_t sampler_tid;

static void
psi_some(const char *path, char *out, size_t len)
{
	char b[256], *p;

	slurp(path, b, sizeof(b));
	p = strstr(b, "avg10=");
	snprintf(out, len, "%.*s", p ? 11 : 1, p ? p : "-");
}

static void *
observer(void *arg)
{
	char path[128], b[512], *p;
	struct timespec sl = { 0, 50000000 };
	struct obs *o;

	(void)arg;
	for (;;) {
		nanosleep(&sl, NULL);
		o = &ring[rhead % RING];
		o->mono = ns(CLOCK_MONOTONIC);
		snprintf(path, sizeof(path), "/proc/self/task/%d/stat",
		    (int)sampler_tid);
		slurp(path, b, sizeof(b));
		p = strrchr(b, ')');
		o->state = (p && p[1] == ' ') ? p[2] : '?';
		snprintf(path, sizeof(path), "/proc/self/task/%d/wchan",
		    (int)sampler_tid);
		slurp(path, o->wchan, sizeof(o->wchan));
		psi_some("/proc/pressure/cpu", o->psi_cpu, sizeof(o->psi_cpu));
		psi_some("/proc/pressure/io", o->psi_io, sizeof(o->psi_io));
		rhead++;
	}
	return (NULL);
}

static int sync_sock = -1;
static int mark_sock = -1;	/* parere #38: marcatore dei buchi all'host, senza risposta letta */
static struct sockaddr_in sync_host;

/* thread a parte: un'attesa della risposta non deve mai fermare il campionatore */
static void *
syncer(void *arg)
{
	char msg[64], rep[128];
	int64_t t1, t4;
	ssize_t n;

	(void)arg;
	for (;;) {
		t1 = ns(CLOCK_REALTIME);
		snprintf(msg, sizeof(msg), "%lld", (long long)t1);
		sendto(sync_sock, msg, strlen(msg), 0,
		    (struct sockaddr *)&sync_host, sizeof(sync_host));
		n = recv(sync_sock, rep, sizeof(rep) - 1, 0);
		t4 = ns(CLOCK_REALTIME);
		if (n > 0) {
			rep[n] = 0;
			printf("SYNC %lld %lld %s\n", (long long)t1,
			    (long long)t4, rep);
		}
		sleep(1);
	}
	return (NULL);
}

static void
schedstat(long long *run, long long *wait, long long *slices)
{
	char path[128], b[128];

	snprintf(path, sizeof(path), "/proc/self/task/%d/schedstat",
	    (int)sampler_tid);
	*run = *wait = *slices = -1;
	if (slurp(path, b, sizeof(b)) == 0)
		sscanf(b, "%lld %lld %lld", run, wait, slices);
}

int
main(int argc, char **argv)
{
	int64_t dur = (argc > 1 ? atoll(argv[1]) : 600) * 1000000000LL;
	int64_t m0, last, lastr, m, r, g;
	long long run0, wait0, sl0, run1, wait1, sl1, st0, st1;
	int cpu0, cpu1, holes = 0;
	struct timespec sl = { 0, 10000000 };
	pthread_t th, ts;
	unsigned i;

	setvbuf(stdout, NULL, _IOLBF, 0);
	sampler_tid = (pid_t)syscall(SYS_gettid);
	pthread_create(&th, NULL, observer, NULL);
	if (argc > 3) {
		struct timeval tv = { 0, 300000 };

		sync_sock = socket(AF_INET, SOCK_DGRAM, 0);
		memset(&sync_host, 0, sizeof(sync_host));
		sync_host.sin_family = AF_INET;
		sync_host.sin_port = htons((uint16_t)atoi(argv[3]));
		inet_pton(AF_INET, argv[2], &sync_host.sin_addr);
		setsockopt(sync_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
		mark_sock = socket(AF_INET, SOCK_DGRAM, 0);
		pthread_create(&ts, NULL, syncer, NULL);
	}
	printf("INIZIO tid=%d mono=%lld real=%lld\n", (int)sampler_tid,
	    (long long)ns(CLOCK_MONOTONIC), (long long)ns(CLOCK_REALTIME));
	m0 = last = ns(CLOCK_MONOTONIC);
	lastr = ns(CLOCK_REALTIME);
	schedstat(&run0, &wait0, &sl0);
	st0 = steal();
	cpu0 = sched_getcpu();
	for (;;) {
		nanosleep(&sl, NULL);
		m = ns(CLOCK_MONOTONIC);
		r = ns(CLOCK_REALTIME);
		g = m - last;
		schedstat(&run1, &wait1, &sl1);
		st1 = steal();
		cpu1 = sched_getcpu();
		if (g >= GAP_NS) {
			holes++;
			if (mark_sock >= 0) {
				char mk[128];

				snprintf(mk, sizeof(mk), "BUCO %lld %lld %lld",
				    (long long)(g / 1000000), (long long)lastr,
				    (long long)r);
				sendto(mark_sock, mk, strlen(mk), 0,
				    (struct sockaddr *)&sync_host, sizeof(sync_host));
			}
			printf("BUCO %lld ms da mono=%lld real=%lld a mono=%lld "
			    "real=%lld cpu %d->%d run+%lldus attesa+%lldus "
			    "volte+%lld steal+%lld\n", (long long)(g / 1000000),
			    (long long)last, (long long)lastr, (long long)m,
			    (long long)r, cpu0, cpu1, (run1 - run0) / 1000,
			    (wait1 - wait0) / 1000, sl1 - sl0, st1 - st0);
			/* campioni dell'osservatore dentro il buco */
			for (i = rhead - RING + 1; i != rhead; i++) {
				struct obs *o = &ring[i % RING];

				if (o->mono > last && o->mono < m)
					printf("  oss +%lldms stato=%c wchan=%s "
					    "psi_cpu %s psi_io %s\n",
					    (long long)((o->mono - last) / 1000000),
					    o->state, o->wchan, o->psi_cpu,
					    o->psi_io);
			}
		}
		last = m;
		lastr = r;
		run0 = run1; wait0 = wait1; sl0 = sl1; st0 = st1; cpu0 = cpu1;
		if (m - m0 >= dur)
			break;
	}
	printf("FINE buchi=%d\n", holes);
	return (0);
}
