/*
 * Claude 20/10/2026 fase A (parere #23): orologio di Linux in WSL2 sotto carico.
 * Campiona CLOCK_MONOTONIC e CLOCK_REALTIME ogni 10 ms. Segnala: salti
 * all'indietro del monotono, buchi (pause del campionatore > 200 ms), e la
 * deriva tra intervalli monotoni e reali. Riepilogo ogni 60 s su stdout.
 * uso: clockmon <secondi>
 */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

static int64_t
ns(clockid_t c)
{
	struct timespec t;

	clock_gettime(c, &t);
	return ((int64_t)t.tv_sec * 1000000000LL + t.tv_nsec);
}

int
main(int argc, char **argv)
{
	int64_t dur = (argc > 1 ? atoll(argv[1]) : 600) * 1000000000LL;
	int64_t m0 = ns(CLOCK_MONOTONIC), r0 = ns(CLOCK_REALTIME);
	int64_t last = m0, rep = m0, m, r, g;
	int64_t maxgap = 0, maxgap_tot = 0, back = 0, holes = 0, n = 0;
	struct timespec sl = { 0, 10000000 };

	for (;;) {
		nanosleep(&sl, NULL);
		m = ns(CLOCK_MONOTONIC);
		r = ns(CLOCK_REALTIME);
		g = m - last;
		n++;
		if (g < 0) {
			back++;
			printf("!!! MONOTONO ALL'INDIETRO di %lld ns\n",
			    (long long)-g);
		}
		if (g > maxgap)
			maxgap = g;
		if (g > maxgap_tot)
			maxgap_tot = g;
		if (g > 200000000LL) {
			holes++;
			printf("buco di %lld ms a %lld s\n",
			    (long long)(g / 1000000),
			    (long long)((m - m0) / 1000000000));
		}
		last = m;
		if (m - rep >= 60000000000LL) {
			printf("t=%llds campioni=%lld gapmax_min=%.1fms "
			    "gapmax=%.1fms buchi=%lld indietro=%lld "
			    "deriva(real-mono)=%.3fms\n",
			    (long long)((m - m0) / 1000000000), (long long)n,
			    maxgap / 1e6, maxgap_tot / 1e6, (long long)holes,
			    (long long)back, ((r - r0) - (m - m0)) / 1e6);
			fflush(stdout);
			maxgap = 0;
			rep = m;
		}
		if (m - m0 >= dur)
			break;
	}
	printf("FINE campioni=%lld gapmax=%.1fms buchi=%lld indietro=%lld "
	    "deriva=%.3fms\n", (long long)n, maxgap_tot / 1e6,
	    (long long)holes, (long long)back,
	    ((ns(CLOCK_REALTIME) - r0) - (ns(CLOCK_MONOTONIC) - m0)) / 1e6);
	return (back ? 1 : 0);
}
