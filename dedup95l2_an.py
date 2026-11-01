#!/usr/local/bin/python3
# dedup95l2_an.py -- Claude 27/10/2026, pareri #95 §4.2-4.4 e #96: analisi OFFLINE delle finestre
# di LIVELLO 2 (dedup95l2.d): insiemi ESATTI di GPA delle tabelle EPT12 lette dalla scansione e
# loro sovrapposizione fra VP. Etichette: SAME_GPA_SET_ONLY / CONTENT_IDENTITY_UNPROVEN (stesse
# GPA non vuol dire stessi CONTENUTI ne' assenza di scritture).
#
# FINESTRA (#96 §3, §6). Intervallo ATTIVO = [ATTIVA inizio, ATTIVA fine] (primo e ultimo
# tick-1ms, sonde certamente attive), NON la durata nominale ne' BEGIN (WARMUP). Per finestra:
# verdetto COMPLETE/INCOMPLETE con i motivi; nessuna finestra si scarta dai log. INCOMPLETE se:
# marcatori assenti, END assente, stderr non vuoto (drop, errori di indirizzo), righe malformate,
# righe H != CONTI, una qualsiasi radice di un'operazione intera con H1 != h1 o H2 != h2 (i due
# siti caller SEPARATAMENTE), GPA distinte della passata 1 != ntr (fb in {0,RACE,VERIFY}), righe H
# di operazioni inesistenti, rientri, vcpuid/kept incoerenti.
# OPERAZIONI usate: intere (I, R, O) con t0 >= inizio e t1 <= fine dell'intervallo ATTIVO; le
# altre si contano e si scartano (aperte alla fine: I senza O).
# GRUPPI (chiave primaria pid + EPTP12 completo, finestra ancorata W). GROUP_EDGE_CENSORED:
#   sinistra: la partizione ancorata e' certa solo da un ancoraggio r con t0(r) - W >= inizio e
#             NESSUN record della stessa chiave in [t0(r) - W, t0(r)): da li' in poi e' identica a
#             quella che si otterrebbe col carico intero; prima, censurato;
#   destra:   censurato se ancora + W > fine, o se esiste un'operazione aperta (I senza O) con
#             t0 <= ancora + W (un membro o un ancoraggio precedente potrebbe mancare).
# METRICHE (#96 §5), solo gruppi multi-VP NON censurati, A_i = GPA distinte della passata 1:
#   R_pages = (N - U) / N,  N = sum |A_i|, U = |unione A_i|  (frazione di PAGINE, senza unita');
#   q_i = [sum_{g in A_i} (1 - 1/m_g)] / |A_i|  (m_g = radici del gruppo che leggono g; 0 se A_i vuoto)
#   Q_cpu_proxy = sum s_i q_i / sum s_j   su TUTTE le radici intere delle finestre valide (s =
#   servizio on-CPU della radice); Q_cpu_proxy_grouped: denominatore = radici dei gruppi validi.
#   Una proxy: non dice che quel lavoro sia risparmiabile ne' sicuro da evitare.
# CAMPIONE (#96 §3): SAMPLE_SUFFICIENT se finestre COMPLETE >= 15 (su quelle pianificate) e
#   gruppi multi-VP validi a 1 ms >= 100; altrimenti SAMPLE_INSUFFICIENT. Nessuna selezione dopo.
# PERTURBAZIONE (#96 §4), dalla traccia di livello 1 della STESSA sessione, operazioni intere
#   entrate DENTRO gli intervalli attivi contro FUORI, STRATIFICATE per (ntr <200/200-499/>=500,
#   nc 0/>0, tentativi 1/>=2, FULL/PARTIAL): elapsed (timestamp) E servizio (vtimestamp, che
#   NON vede il tempo delle sonde: d(7)); INVEPT al secondo effettivo; race, FULL, budget per
#   radice; mix (distanza di variazione totale fra gli strati). PERTURBATION_SUSPECTED se elapsed
#   o servizio stratificati > 10%, race > 25%, o mix > 0,20. Nessuna soglia esclude un disturbo
#   non rilevato.
# DECISIONE pre-registrata (#96 §5), chiave primaria a 1 ms:
#   campione insufficiente o perturbazione sospetta  -> NESSUNA_DECISIONE
#   R_pages < 10% e Q_cpu_proxy < 10%                -> DEPRIORITIZZARE
#   R_pages >= 50% e Q_cpu_proxy >= 30%              -> PROGETTARE_SOLO_AUDIT_STATICO
#   altrimenti                                       -> ANALISI_OFFLINE
# Uso: dedup95l2_an.py [--l1 lat-05.txt] [--pianificate 20] finestra1.txt [...]
import argparse, importlib.util, os, re, sys
from collections import Counter, defaultdict

spec = importlib.util.spec_from_file_location('an', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dedup92_an.py'))
an = importlib.util.module_from_spec(spec)
spec.loader.exec_module(an)

W_DEC = 1000000
MIN_FINESTRE, MIN_GRUPPI = 15, 100
S_ELAPSED, S_RACE, S_MIX, MIN_STRATO = 0.10, 0.25, 0.20, 5

def leggi(testo):
	P = an.leggi(testo)
	g = lambda r: (lambda m: int(m.group(1)) if m else None)(re.search(r, testo, re.M))
	P['richiesta'] = g(r'^FINESTRA richiesta=(\d+)')
	P['ms'] = g(r'^FINESTRA richiesta=\d+ ms=(\d+)')
	P['a'] = g(r'^ATTIVA inizio=(\d+)')
	P['b'] = g(r'^ATTIVA fine=(\d+)')
	P['I'] = [(int(t), int(x)) for t, x in re.findall(r'^I tid=(\d+) t0=(\d+)$', testo, re.M)]
	return P

def insiemi(P):
	h = defaultdict(lambda: {'p1': [], 'p2': []})
	for x in P['H']:
		h[(x['tid'], x['t0'], x['k'])]['p%d' % x['p']].append(x['gpa'])
	return h

def aperte(P):
	"""t0 delle operazioni aperte alla fine: righe I (stesso self->t della riga O) senza O."""
	o = {(x['tid'], x['t0']) for x in P['O']}
	return sorted(t for tid, t in P['I'] if (tid, t) not in o)

def integrita(P, err, nvcpu=8, retries=1):
	C = []
	def c(nome, ok, det=''):
		C.append((nome, bool(ok), det))
	for n, ok, det in an.integrita(P, err, nvcpu, retries):
		if not n.startswith(('chiusura', 'fotografie', 'intervallo di lettura')):
			C.append((n, ok, det))
	ci = P['conti']
	c('marcatori della finestra ATTIVA (inizio e fine)', P['a'] is not None and P['b'] is not None and P['b'] > P['a'],
		'%s..%s' % (P['a'], P['b']))
	c('righe H = CONTI nh1 + nh2', len(P['H']) == ci.get('nh1', 0) + ci.get('nh2', 0),
		'%d / %d' % (len(P['H']), ci.get('nh1', 0) + ci.get('nh2', 0)))
	c('righe I = CONTI nb (un ingresso per operazione)', len(P['I']) == ci.get('nb', 0), '%d / %d' % (len(P['I']), ci.get('nb', 0)))
	io = {(x['tid'], x['t0']) for x in P['O']}
	c('ogni O ha la sua I (aggancio esatto)', io <= set(P['I']), len(io - set(P['I'])))
	c('chiavi (tid, t0) uniche nelle righe I e O (nessuna collisione)', len(set(P['I'])) == len(P['I']) and len(io) == len(P['O']),
		'I %d/%d, O %d/%d' % (len(set(P['I'])), len(P['I']), len(io), len(P['O'])))
	h = insiemi(P)
	op = {(o['tid'], o['t0']) for o in P['O']}
	ultimo = {}
	for o in P['O']:
		ultimo[o['tid']] = max(ultimo.get(o['tid'], 0), o['t0'])
	fuori = {(t, t0) for (t, t0, k) in h if (t, t0) not in op}
	c('righe H fuori dalle operazioni intere solo di operazioni aperte alla fine',
		all(t0 > ultimo.get(t, -1) for t, t0 in fuori) and len(fuori) <= max(ci.get('nb', 0) - ci.get('no', 0), 0), len(fuori))
	mis1 = mis2 = dist = 0
	s1 = s2 = h1 = h2 = 0
	kmax = defaultdict(int)
	for r in P['R']:
		kmax[(r['tid'], r['t0'])] = max(kmax[(r['tid'], r['t0'])], r['k'])
		if (r['tid'], r['t0']) not in op:
			continue
		x = h.get((r['tid'], r['t0'], r['k']), {'p1': [], 'p2': []})
		s1 += len(x['p1']); s2 += len(x['p2']); h1 += r['h1']; h2 += r['h2']
		mis1 += len(x['p1']) != r['h1']
		mis2 += len(x['p2']) != r['h2']
		if r['fb'] in an.FB_ESATTO and r['ntr'] > 0 and len(set(x['p1'])) != r['ntr']:
			dist += 1
	c('sito +0xcb8: per radice H1 = h1 (VST_H_SCAN1)', mis1 == 0, 'radici errate %d; totali %d / %d' % (mis1, s1, h1))
	c('sito +0x10eb: per radice H2 = h2 (VST_H_SCAN2)', mis2 == 0, 'radici errate %d; totali %d / %d' % (mis2, s2, h2))
	c('fb in {0,RACE,VERIFY}: GPA distinte della passata 1 = ntr', dist == 0, dist)
	vuote = sum(1 for r in P['R'] if (r['tid'], r['t0']) in op and r['ntr'] > 0 and not r['fb'] & an.FB_PRIMA
		and not h.get((r['tid'], r['t0'], r['k']), {'p1': []})['p1'])
	c('#97 §1: radici con ntr > 0 hanno H1 > 0', vuote == 0, vuote)
	oltre = sum(1 for (t, t0, k) in h if (t, t0) in op and k > kmax.get((t, t0), 0))
	c('righe H attribuite a una radice esistente', oltre == 0, oltre)
	return C

def operazioni_usate(P):
	"""(chiavi delle operazioni intere dentro l'intervallo ATTIVO, conteggi degli scarti)."""
	a, b = P['a'], P['b']
	usate, n = set(), Counter()
	for o in P['O']:
		if a is not None and b is not None and o['t0'] >= a and o['t1'] <= b:
			usate.add((o['tid'], o['t0']))
		else:
			n['fuori_intervallo'] += 1
	n['aperte'] = len(aperte(P))
	return usate, n

def censura(P, gruppi, W):
	"""{id(gruppo): motivo} per i gruppi censurati (vedi testata)."""
	a, b = P['a'], P['b']
	ap = aperte(P)
	t_open = ap[0] if ap else None
	per = defaultdict(list)
	pid = {(o['tid'], o['t0']): o['pid'] for o in P['O']}
	for r in P['R']:
		if (r['tid'], r['t0']) in pid:
			per[(pid[(r['tid'], r['t0'])], r['e'])].append(r['t0'])
	sicuro = {}
	for k, ts in per.items():
		ts = sorted(ts)
		sicuro[k] = None
		for i, t in enumerate(ts):
			if t - W >= a and (i == 0 or ts[i - 1] < t - W):
				sicuro[k] = t
				break
	out = {}
	for chiave, m in gruppi:
		g0 = min(t0 for t0, _, _ in m)
		s = sicuro.get(chiave)
		if s is None or g0 < s:
			out[id(m)] = 'sinistra'
		elif g0 + W > b or (t_open is not None and t_open <= g0 + W):
			out[id(m)] = 'destra'
	return out

def misure(P, W):
	"""Metriche di UNA finestra completa (gruppi validi = multi-VP non censurati)."""
	usate, scarti = operazioni_usate(P)
	O = [o for o in P['O'] if (o['tid'], o['t0']) in usate]
	sr = an.servizio_radici(P['R'], O)
	Rv = [r for r in P['R'] if id(r) in sr]
	h = insiemi(P)
	A = {id(r): frozenset(h.get((r['tid'], r['t0'], r['k']), {'p1': []})['p1']) for r in Rv}
	G = [g for g in an.gruppi(Rv, O, W) if len(g[1]) >= 2]
	cens = censura(P, G, W)
	x = Counter(scarti)
	x['radici'] = len(Rv)
	x['op'] = len(O)
	x['op_multiradice'] = sum(1 for o in O if o['nk'] > 1)
	x['s_tot'] = sum(sr.values())
	x['gruppi_multi'] = len(G)
	x['censurati_sx'] = sum(1 for v in cens.values() if v == 'sinistra')
	x['censurati_dx'] = sum(1 for v in cens.values() if v == 'destra')
	ov = []
	for chiave, m in G:
		if id(m) in cens:
			continue
		rr = [r for _, r, _ in m]
		S = [A[id(r)] for r in rr]
		mg = Counter(g for a in S for g in a)
		x['gruppi'] += 1
		x['N'] += sum(len(a) for a in S)
		x['U'] += len(mg)
		x['uguali'] += len(set(S)) == 1
		# #97 §3: U e m_g sono LOCALI al gruppo (mg si ricostruisce per ogni gruppo); fra gruppi e
		# finestre si SOMMANO N e U, mai un'unione globale
		for r, a in zip(rr, S):
			x['vuoti'] += not a
			q = sum(1 - 1 / mg[g] for g in a) / len(a) if a else 0.0
			x['sq'] += sr[id(r)] * q
			x['s_gruppi'] += sr[id(r)]
		for i in range(len(S)):
			for j in range(i + 1, len(S)):
				if S[i] and S[j]:
					ov.append(len(S[i] & S[j]) / min(len(S[i]), len(S[j])))
	return x, ov

def rapporti(x):
	R = (x['N'] - x['U']) / x['N'] if x['N'] else None
	Q = x['sq'] / x['s_tot'] if x['s_tot'] else None
	Qg = x['sq'] / x['s_gruppi'] if x['s_gruppi'] else None
	return R, Q, Qg

def strato(o, rr, retries):
	ntr = max([r['ntr'] for r in rr] or [0])
	return ('ntr<200' if ntr < 200 else 'ntr<500' if ntr < 500 else 'ntr>=500',
		'nc>0' if any(r['nc'] for r in rr) else 'nc=0',
		'a>=2' if any((an.tentativi(r, retries)[0] or 0) >= 2 for r in rr) else 'a=1',
		'FULL' if any(r['fb'] for r in rr) else 'PART')

def perturbazione(l1, intervalli, retries=1):
	"""Dentro contro fuori gli intervalli ATTIVI, dalla traccia di livello 1."""
	P = an.leggi(open(l1, errors='replace').read())
	per = defaultdict(list)
	for r in P['R']:
		per[(r['tid'], r['t0'])].append(r)
	g = {'dentro': defaultdict(list), 'fuori': defaultdict(list)}
	n = {'dentro': Counter(), 'fuori': Counter()}
	for o in P['O']:
		rr = per.get((o['tid'], o['t0']), [])
		k = 'dentro' if any(a <= o['t0'] and o['t1'] <= b for a, b in intervalli) else 'fuori'
		if k == 'fuori' and any(a <= o['t0'] <= b or a <= o['t1'] <= b for a, b in intervalli):
			n['dentro']['a_cavallo'] += 1
			continue
		g[k][strato(o, rr, retries)].append((o['t1'] - o['t0'], o['sv']))
		n[k]['op'] += 1
		for r in rr:
			n[k]['radici'] += 1
			n[k]['race'] += bool(r['fb'] & 0x40)
			n[k]['full'] += r['fb'] != 0
			n[k]['budget'] += r['fb'] == 0x40 and (an.tentativi(r, retries)[0] or 0) <= retries
	dur_in = sum(b - a for a, b in intervalli)
	t = [o['t0'] for o in P['O']]
	dur_tot = (max(t) - min(t)) if t else 0
	out = {'n': n, 'dur_in': dur_in, 'dur_out': dur_tot - dur_in}
	# rapporti stratificati, pesati sulle operazioni DENTRO, solo strati con >= MIN_STRATO per lato
	for i, nome in ((0, 'elapsed'), (1, 'servizio')):
		num = den = 0.0
		for s, v in g['dentro'].items():
			f = g['fuori'].get(s, [])
			if len(v) >= MIN_STRATO and len(f) >= MIN_STRATO:
				mi = sum(x[i] for x in v) / len(v)
				mf = sum(x[i] for x in f) / len(f)
				if mf:
					num += len(v) * mi / mf
					den += len(v)
		out[nome] = num / den - 1 if den else None
		out[nome + '_copertura'] = den / max(n['dentro']['op'], 1)
	strati = set(g['dentro']) | set(g['fuori'])
	td, tf = max(n['dentro']['op'], 1), max(n['fuori']['op'], 1)
	out['mix'] = sum(abs(len(g['dentro'].get(s, [])) / td - len(g['fuori'].get(s, [])) / tf) for s in strati) / 2
	for k in ('race', 'full', 'budget'):
		pd = n['dentro'][k] / max(n['dentro']['radici'], 1)
		pf = n['fuori'][k] / max(n['fuori']['radici'], 1)
		out[k] = (pd / pf - 1) if pf else None
	out['rate'] = ((n['dentro']['op'] / out['dur_in']) / (n['fuori']['op'] / out['dur_out']) - 1) if out['dur_in'] and out['dur_out'] and n['fuori']['op'] else None
	sosp = []
	for k, s in (('elapsed', S_ELAPSED), ('servizio', S_ELAPSED), ('race', S_RACE)):
		if out[k] is not None and abs(out[k]) > s:
			sosp.append(k)
	if out['mix'] > S_MIX:
		sosp.append('mix')
	if out['elapsed'] is None or out['servizio'] is None:
		sosp.append('strati insufficienti')
	out['sospetta'] = sosp
	return out

def decisione(sufficiente, sospetta, R, Q):
	if not sufficiente or sospetta or R is None or Q is None:
		return 'NESSUNA_DECISIONE'
	if R < 0.10 and Q < 0.10:
		return 'DEPRIORITIZZARE'
	if R >= 0.50 and Q >= 0.30:
		return 'PROGETTARE_SOLO_AUDIT_STATICO'
	return 'ANALISI_OFFLINE'

def pct(v):
	return 'n/d' if v is None else '%.1f%%' % (100 * v)

def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('--l1')
	ap.add_argument('--pianificate', type=int, default=20)
	ap.add_argument('--nvcpu', type=int, default=8)
	ap.add_argument('--retries', type=int, default=1)
	ap.add_argument('--min-finestre', type=int, default=MIN_FINESTRE)
	ap.add_argument('--min-gruppi', type=int, default=MIN_GRUPPI)
	ap.add_argument('finestre', nargs='+')
	a = ap.parse_args()
	agg = {w: Counter() for w in (1000000, 5000000)}
	perfin = {w: [] for w in agg}
	ovs = {w: [] for w in agg}
	intervalli, complete, t_rif = [], 0, None
	for f in a.finestre:
		P = leggi(open(f, errors='replace').read())
		e = f[:-4] + '.err' if f.endswith('.txt') else f + '.err'
		err = open(e).read() if os.path.exists(e) else ''
		C = integrita(P, err, a.nvcpu, a.retries)
		ko = [n for n, k, _ in C if not k]
		det = {n: d for n, k, d in C}
		if P['a'] is not None and P['b'] is not None:
			intervalli.append((P['a'], P['b']))
		t_rif = t_rif or P['a']
		print('== %s: %s' % (f, 'COMPLETE' if not ko else 'INCOMPLETE: ' + '; '.join(ko)))
		print('   richiesta %s, attiva %s .. %s (%.1f ms; nominale %s ms); %s; %s'
			% (P['richiesta'], P['a'], P['b'], (P['b'] - P['a']) / 1e6 if P['a'] and P['b'] else float('nan'), P['ms'],
			det.get('sito +0xcb8: per radice H1 = h1 (VST_H_SCAN1)'), det.get('sito +0x10eb: per radice H2 = h2 (VST_H_SCAN2)')))
		if ko:
			continue
		complete += 1
		for w in agg:
			x, ov = misure(P, w)
			agg[w].update(x)
			ovs[w] += ov
			R, Q, Qg = rapporti(x)
			perfin[w].append((R, Q))
			print('   %g ms: radici usate %d (scartate: fuori intervallo %d, aperte %d), gruppi multi-VP %d, censurati sx/dx %d/%d, VALIDI %d; R_pages %s, Q_cpu_proxy %s'
				% (w / 1e6, x['radici'], x['fuori_intervallo'], x['aperte'], x['gruppi_multi'], x['censurati_sx'], x['censurati_dx'], x['gruppi'], pct(R), pct(Q)))
	print('FINESTRE: complete %d su %d presenti, %d pianificate' % (complete, len(a.finestre), a.pianificate))
	for w in agg:
		R, Q, Qg = rapporti(agg[w])
		rs = sorted(r for r, _ in perfin[w] if r is not None)
		qs = sorted(q for _, q in perfin[w] if q is not None)
		print('-- %g ms (SAME_GPA_SET_ONLY / CONTENT_IDENTITY_UNPROVEN): gruppi validi %d (censurati %d); N %d, U %d'
			% (w / 1e6, agg[w]['gruppi'], agg[w]['censurati_sx'] + agg[w]['censurati_dx'], agg[w]['N'], agg[w]['U']))
		print('   R_pages_total %s; Q_cpu_proxy %s; Q_cpu_proxy_grouped %s (denominatore ristretto, a parte); gruppi con insiemi identici %d; overlap p50 %s'
			% (pct(R), pct(Q), pct(Qg), agg[w]['uguali'], '%.2f' % an.q(ovs[w], 50) if ovs[w] else 'n/d'))
		print('   radici con insieme VUOTO nei gruppi validi %d (q = 0 per convenzione); operazioni con piu\' radici %d su %d (%s: s_i puo\' includere lo svuotamento della precedente)'
			% (agg[w]['vuoti'], agg[w]['op_multiradice'], agg[w]['op'], pct(agg[w]['op_multiradice'] / agg[w]['op']) if agg[w]['op'] else 'n/d'))
		if rs:
			print('   per finestra: R_pages p10/p50/p90 %s/%s/%s; Q_cpu_proxy p10/p50/p90 %s/%s/%s'
				% (pct(an.q(rs, 10)), pct(an.q(rs, 50)), pct(an.q(rs, 90)), pct(an.q(qs, 10)), pct(an.q(qs, 50)), pct(an.q(qs, 90))))
	suff = complete >= a.min_finestre and agg[W_DEC]['gruppi'] >= a.min_gruppi
	print('CAMPIONE=%s (complete %d >= %d e gruppi validi a 1 ms %d >= %d)' % ('SAMPLE_SUFFICIENT' if suff else 'SAMPLE_INSUFFICIENT',
		complete, a.min_finestre, agg[W_DEC]['gruppi'], a.min_gruppi))
	sosp = ['traccia di livello 1 assente']
	if a.l1 and intervalli:
		p = perturbazione(a.l1, intervalli, a.retries)
		n = p['n']
		print('-- PERTURBAZIONE (stessa sessione; dentro %d op, fuori %d, a cavallo %d; stratificata, copertura %s)'
			% (n['dentro']['op'], n['fuori']['op'], n['dentro']['a_cavallo'], pct(p['elapsed_copertura'])))
		print('   elapsed %s, servizio %s (vtimestamp: NON vede il tempo delle sonde), INVEPT/s %s, race/radice %s, FULL/radice %s, budget/radice %s, mix (TVD) %.3f'
			% (pct(p['elapsed']), pct(p['servizio']), pct(p['rate']), pct(p['race']), pct(p['full']), pct(p['budget']), p['mix']))
		sosp = p['sospetta']
		print('PERTURBAZIONE=%s (nessuna soglia esclude un disturbo non rilevato)' % ('PERTURBATION_SUSPECTED: ' + ', '.join(sosp) if sosp else 'nessun allarme'))
	else:
		print('PERTURBAZIONE=NON VALUTATA (manca --l1): PERTURBATION_SUSPECTED')
	R, Q, _ = rapporti(agg[W_DEC])
	print('DECISIONE_PREREGISTRATA=%s (1 ms; R_pages %s, Q_cpu_proxy %s)' % (decisione(suff, sosp, R, Q), pct(R), pct(Q)))
	sys.exit(0 if complete == len(a.finestre) else 3)

if __name__ == '__main__':
	main()
