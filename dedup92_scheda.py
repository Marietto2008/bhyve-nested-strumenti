#!/usr/local/bin/python3
# dedup92_scheda.py -- Claude 27/10/2026, parere #95 §4.1 e §5.3: UNA analisi offline delle
# cardinalita' ntr/nc nei gruppi del livello 1, sulla traccia gia' congelata (sola lettura).
# NON rivela le GPA: serve a scegliere finestre e VP per un livello 2. Nessun verdetto nuovo.
#   1. ntr per VP; nei gruppi (1 e 5 ms, chiave primaria): min/max, rapporto min/max,
#      sum(ntr) - max(ntr) = tetto della rilettura SE gli insiemi fossero annidati
#      (0 se disgiunti: l'intersezione vera sta fra i due e solo il livello 2 la misura)
#   2. classi nc=0 / nc>0 / FULL / MISTO come quota del servizio TOTALE delle radici
#   3. VP per gruppo, sovrapposizione nel tempo, ripetizione dei gruppi sulla stessa EPTP12
#   4. costo aggregato (CPU del gestore) contro tempo reale: quota del tempo vCPU, e per
#      gruppo servizio sommato contro ampiezza reale
# Uso: dedup92_scheda.py <lat-0N.txt> <durata in s, 0 = dalla traccia> [nvcpu]
import importlib.util, math, os, sys
from collections import Counter, defaultdict

AN = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dedup92_an.py')
spec = importlib.util.spec_from_file_location('an', AN)
an = importlib.util.module_from_spec(spec)
spec.loader.exec_module(an)

def q(v, p):
	return an.q(v, p)

def main():
	traccia, comp_s = sys.argv[1], float(sys.argv[2])
	nvcpu = int(sys.argv[3]) if len(sys.argv) > 3 else 8
	P = an.leggi(open(traccia, errors='replace').read())
	sr = an.servizio_radici(P['R'], P['O'])
	Rv = [r for r in P['R'] if id(r) in sr]
	O = P['O']
	tot_srv = sum(sr.values())
	print('== scheda offline (#95 §4.1) su %s' % traccia)
	print('   radici %d, servizio delle radici (root_oncpu_approx) %.3f s' % (len(Rv), tot_srv / 1e9))
	print('-- 1. ntr per VP: p50 / p95 / media / max')
	pv = defaultdict(list)
	for r in Rv:
		pv[r['vc']].append(r['ntr'])
	for vc in sorted(pv):
		v = pv[vc]
		print('   vCPU %d: %4d / %4d / %6.1f / %4d  (%d radici)' % (vc, q(v, 50), q(v, 95), sum(v) / len(v), max(v), len(v)))
	for W in (1000000, 5000000):
		G = [g for g in an.gruppi(Rv, O, W) if len(g[1]) >= 2]
		rapp, somma, massimo, tetto = [], 0, 0, 0
		for _, m in G:
			n = [r['ntr'] for _, r, _ in m]
			rapp.append(min(n) / max(n) if max(n) else 1.0)
			somma += sum(n)
			massimo += max(n)
		tetto = somma - massimo
		print('-- 1. gruppi %g ms (%d): rapporto min/max di ntr p10/p50/p90 %.2f/%.2f/%.2f'
			% (W / 1e6, len(G), q(rapp, 10), q(rapp, 50), q(rapp, 90)))
		print('   tabelle tracciate nei gruppi: sum(ntr) %d; sum(max ntr) %d; tetto della rilettura SE annidati %d = %.1f%% delle tabelle (0 se disgiunti)'
			% (somma, massimo, tetto, 100 * tetto / somma if somma else float('nan')))
		x = an.statistiche_gruppi(Rv, O, W, sr, tot_srv, an.chiave_completa)
		print('-- 2. classi, quota del servizio TOTALE: ' + ', '.join('%s %d gruppi %.1f%%' % (k, v[0], 100 * v[1] / tot_srv)
			for k, v in x['classi'].items()))
		mem = Counter(len(m) for _, m in G)
		print('-- 3. VP per gruppo: %s; sovrapposti nel tempo %d (%.1f%%)' % (dict(sorted(mem.items())), x['sovrapposti'], 100 * x['sovrapposti'] / max(len(G), 1)))
		inizi = sorted(min(t0 for t0, _, _ in m) for _, m in G)
		gap = [b - a for a, b in zip(inizi, inizi[1:])]
		dur = (max(o['t1'] for o in O) - min(o['t0'] for o in O)) / 1e9
		print('   ripetizione: %.1f gruppi/s; intervallo fra gruppi consecutivi p10/p50/p90 %.2f/%.2f/%.2f ms'
			% (len(G) / dur, q(gap, 10) / 1e6, q(gap, 50) / 1e6, q(gap, 90) / 1e6))
		ofine = {(o['tid'], o['t0']): o['t1'] for o in O}
		ampiezza = sum(max(ofine[(r['tid'], r['t0'])] for _, r, _ in m) - min(r['t0'] for _, r, _ in m) for _, m in G)
		print('-- 4. servizio sommato nei gruppi %.1f s contro ampiezza reale sommata dei gruppi %.1f s (rapporto %.2f: il lavoro dei VP e\' in PARALLELO)'
			% (x['servizio'] / 1e9, ampiezza / 1e9, x['servizio'] / ampiezza if ampiezza else float('nan')))
	cpu = sum(o['sv'] for o in O)
	if comp_s <= 0:		# fase senza tempo misurato (ext4): durata della traccia
		comp_s = (max(o['t1'] for o in O) - min(o['t0'] for o in O)) / 1e9
	print('-- 4. CPU del gestore %.1f s su %d vCPU x %.1f s = %.2f%% del tempo vCPU: TETTO del guadagno reale anche eliminando TUTTO il gestore;'
		% (cpu / 1e9, nvcpu, comp_s, 100 * cpu / 1e9 / (nvcpu * comp_s)))
	print('   il beneficio sul tempo di compilazione NON e\' la somma dei tempi CPU (VP in parallelo, race, fault EPT02 a valle).')

if __name__ == '__main__':
	main()
