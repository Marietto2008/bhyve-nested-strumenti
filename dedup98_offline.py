#!/usr/local/bin/python3
# dedup98_offline.py -- Claude 27/10/2026, parere #98 §4.1-4.3: analisi DERIVATA OFFLINE della
# campagna dedup95 (18:01). Sola lettura degli originali; NON cambia NESSUNA_DECISIONE. Nessuna
# nuova sonda, nessuna VM.
#   1. scheda per raffica (finestre con operazioni): gruppi, radici, N, U, R_pages, Q_cpu_proxy,
#      servizio del gestore nella finestra, ampiezza attiva, censura, per VP; ntr=0; peso di
#      ogni raffica e di ogni VP sulle letture ripetute (N - U).
#   2. sensibilita' descrittiva: W = 0,5 e 1 ms; leave-one-burst-out. Robustezza DESCRITTIVA, non
#      correzione della perturbazione, non nuovo cancello.
#   3. controlli negativi dalla traccia di livello 1: dentro gli intervalli ATTIVI contro fuori,
#      complessivo e per strato: ntr, nc, tentativi, FULL, byte per operazione, quota di radici in
#      gruppi fra VP. Differenze = dubbio rafforzato; nessuna differenza = NON prova neutralita'.
# Uso: dedup98_offline.py <cartella 1-A>
import glob, importlib.util, os, re, sys
from collections import Counter, defaultdict

B = os.path.dirname(os.path.abspath(__file__))
def carica(nome, f):
	spec = importlib.util.spec_from_file_location(nome, os.path.join(B, f))
	m = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(m)
	return m
l2 = carica('l2', 'dedup95l2_an.py')
an = l2.an
pct = l2.pct

def finestre(d):
	out = []
	for f in sorted(glob.glob(d + '/l2-05-*.txt'), key=lambda x: int(re.search(r'-(\d+)\.txt$', x).group(1))):
		P = l2.leggi(open(f, errors='replace').read())
		if P['O']:
			out.append((int(re.search(r'-(\d+)\.txt$', f).group(1)), P))
	return out

def scheda(n, P, W):
	x, _ = l2.misure(P, W)
	R, Q, Qg = l2.rapporti(x)
	usate = l2.operazioni_usate(P)[0]
	O = [o for o in P['O'] if (o['tid'], o['t0']) in usate]
	sr = an.servizio_radici(P['R'], O)
	Rv = [r for r in P['R'] if id(r) in sr]
	h = l2.insiemi(P)
	A = {id(r): frozenset(h.get((r['tid'], r['t0'], r['k']), {'p1': []})['p1']) for r in Rv}
	G = [g for g in an.gruppi(Rv, O, W) if len(g[1]) >= 2]
	cens = l2.censura(P, G, W)
	pv = defaultdict(Counter)
	for _, m in G:
		if id(m) in cens:
			continue
		rr = [r for _, r, _ in m]
		mg = Counter(g for r in rr for g in A[id(r)])
		for r in rr:
			a = A[id(r)]
			pv[r['vc']]['radici'] += 1
			pv[r['vc']]['N'] += len(a)
			# letture di questa radice di pagine lette ANCHE da altri membri (quota ripetuta attribuita)
			pv[r['vc']]['rip'] += sum(1 - 1 / mg[g] for g in a)
			pv[r['vc']]['vuoti'] += not a
			pv[r['vc']]['s'] += sr[id(r)]
	zero = [r for r in Rv if r['ntr'] == 0]
	return {'n': n, 'x': x, 'R': R, 'Q': Q, 'Qg': Qg, 'attiva_ms': (P['b'] - P['a']) / 1e6, 'pv': pv,
		'servizio_op': sum(o['sv'] for o in O), 'zero': len(zero), 'zero_s': sum(sr[id(r)] for r in zero), 's_tot': sum(sr.values())}

def stampa_scheda(s):
	x = s['x']
	print('-- raffica nella finestra %d: attiva %.1f ms; radici %d; gruppi multi-VP %d, censurati sx/dx %d/%d, VALIDI %d'
		% (s['n'], s['attiva_ms'], x['radici'], x['gruppi_multi'], x['censurati_sx'], x['censurati_dx'], x['gruppi']))
	print('   N %d, U %d, N-U %d; R_pages %s; Q_cpu_proxy %s (grouped %s); servizio del gestore nella finestra %.1f ms = %.1f%% di 8 vCPU x attiva'
		% (x['N'], x['U'], x['N'] - x['U'], pct(s['R']), pct(s['Q']), pct(s['Qg']), s['servizio_op'] / 1e6, 100 * s['servizio_op'] / (8 * s['attiva_ms'] * 1e6)))
	print('   ntr = 0: %d radici, %.2f%% del servizio delle radici' % (s['zero'], 100 * s['zero_s'] / s['s_tot'] if s['s_tot'] else 0))
	tot_rip = sum(v['rip'] for v in s['pv'].values()) or 1
	print('   per VP: radici / N / quota delle letture ripetute del gruppo attribuita (sum 1-1/m_g) / servizio ms')
	for vc in sorted(s['pv']):
		v = s['pv'][vc]
		print('     vCPU %d: %4d %8d %6.1f%% %8.2f' % (vc, v['radici'], v['N'], 100 * v['rip'] / tot_rip, v['s'] / 1e6))

def somma(schede, escludi=None):
	c = Counter()
	for s in schede:
		if s['n'] != escludi:
			c.update(s['x'])
	return l2.rapporti(c), c

def controlli_negativi(d, intervalli, retries=1):
	P = an.leggi(open(d + '/lat-05.txt', errors='replace').read())
	sr = an.servizio_radici(P['R'], P['O'])
	Rv = [r for r in P['R'] if id(r) in sr]
	O = P['O']
	dentro_op = {(o['tid'], o['t0']) for o in O if any(a <= o['t0'] and o['t1'] <= b for a, b in intervalli)}
	cavallo = {(o['tid'], o['t0']) for o in O if (o['tid'], o['t0']) not in dentro_op and any(a <= o['t0'] <= b or a <= o['t1'] <= b for a, b in intervalli)}
	G = [g for g in an.gruppi(Rv, O, 1000000) if len(g[1]) >= 2]
	in_gruppo = {id(r) for _, m in G for _, r, _ in m}
	agg = {'dentro': defaultdict(list), 'fuori': defaultdict(list)}
	per_strato = {'dentro': defaultdict(list), 'fuori': defaultdict(list)}
	per = defaultdict(list)
	for r in Rv:
		per[(r['tid'], r['t0'])].append(r)
	for o in O:
		k = (o['tid'], o['t0'])
		if k in cavallo:
			continue
		lato = 'dentro' if k in dentro_op else 'fuori'
		rr = per.get(k, [])
		if not rr:
			continue
		st = l2.strato(o, rr, retries)
		v = {'ntr': max(r['ntr'] for r in rr), 'nc': max(r['nc'] for r in rr),
			'a2': int(any((an.tentativi(r, retries)[0] or 0) >= 2 for r in rr)), 'full': int(any(r['fb'] for r in rr)),
			'byte': sum((r['h1'] + r['h2']) * 4096 for r in rr), 'gruppo': int(any(id(r) in in_gruppo for r in rr))}
		for q, val in v.items():
			agg[lato][q].append(val)
		per_strato[lato][st].append(v)
	print('-- 3. controlli negativi (livello 1, stessa sessione): operazioni dentro %d, fuori %d, a cavallo %d (escluse)'
		% (len(agg['dentro']['ntr']), len(agg['fuori']['ntr']), len(cavallo)))
	m = lambda v: sum(v) / len(v) if v else float('nan')
	for q, nome in (('ntr', 'ntr medio'), ('nc', 'nc medio'), ('a2', 'quota con >= 2 tentativi'), ('full', 'quota FULL'),
			('byte', 'byte letti per operazione'), ('gruppo', 'quota in gruppi fra VP (1 ms)')):
		d_, f_ = m(agg['dentro'][q]), m(agg['fuori'][q])
		print('   %-32s dentro %12.4g  fuori %12.4g  rapporto %s' % (nome, d_, f_, '%.3f' % (d_ / f_) if f_ else 'n/d'))
	print('   per strato (>= 5 operazioni per lato): byte per operazione e ntr medio, dentro/fuori')
	for st in sorted(set(per_strato['dentro']) & set(per_strato['fuori'])):
		a, b = per_strato['dentro'][st], per_strato['fuori'][st]
		if len(a) >= 5 and len(b) >= 5:
			print('     %-34s n %4d/%6d  byte %.3f  ntr %.3f  gruppo %.3f' % ('/'.join(st), len(a), len(b),
				m([x['byte'] for x in a]) / m([x['byte'] for x in b]), m([x['ntr'] for x in a]) / m([x['ntr'] for x in b]),
				(m([x['gruppo'] for x in a]) / m([x['gruppo'] for x in b])) if m([x['gruppo'] for x in b]) else float('nan')))
	print('   (differenze rafforzano il dubbio; l\'assenza di differenze NON prova neutralita\' ne\' identita\' di GPA o contenuti)')

def main():
	d = sys.argv[1]
	F = finestre(d)
	print('== parere #98, analisi DERIVATA OFFLINE su %s (DECISIONE_PREREGISTRATA resta NESSUNA_DECISIONE)' % d)
	print('-- 1. schede per raffica (1 ms, chiave primaria, gruppi validi)')
	S = [scheda(n, P, 1000000) for n, P in F]
	for s in S:
		stampa_scheda(s)
	tot = sum(s['x']['N'] - s['x']['U'] for s in S) or 1
	print('   peso di ogni raffica sulle letture ripetute (N-U): ' + ', '.join('finestra %d %.1f%%' % (s['n'], 100 * (s['x']['N'] - s['x']['U']) / tot) for s in S))
	print('-- 2. sensibilita\' DESCRITTIVA (non corregge la perturbazione, non e\' un cancello)')
	for W in (500000, 1000000):
		SW = [scheda(n, P, W) for n, P in F]
		(R, Q, Qg), c = somma(SW)
		print('   W = %.1f ms: gruppi validi %d; R_pages %s; Q_cpu_proxy %s' % (W / 1e6, c['gruppi'], pct(R), pct(Q)))
	for s in S:
		(R, Q, Qg), c = somma(S, escludi=s['n'])
		print('   1 ms senza la raffica della finestra %d: gruppi validi %d; R_pages %s; Q_cpu_proxy %s' % (s['n'], c['gruppi'], pct(R), pct(Q)))
	intervalli = [(P['a'], P['b']) for f in sorted(glob.glob(d + '/l2-05-*.txt')) for P in [l2.leggi(open(f).read())] if P['a'] and P['b']]
	controlli_negativi(d, intervalli)

if __name__ == '__main__':
	main()
