#!/usr/local/bin/python3
# dedup92_an.py -- Claude 27/10/2026, pareri #92 §4 e #93: analisi OFFLINE della traccia di
# livello 1 dedup92.d (gen-dedup92.py). Nessun verdetto di deduplicazione: DESCRIZIONE con le
# etichette dei pareri (GROUP_SAME_EPTP12, COUNTERS_MATCH, CANDIDATE, IDENTITY_UNPROVEN; mai
# DUPLICATE_PROVEN) e la regola di decisione PRE-REGISTRATA del #93 §6.
#
#   COMPLETEZZA della traccia (fail-closed: un record mancante non si ricostruisce):
#     marcatori, stderr di DTrace (drop, errori di indirizzo: un dereferenziamento invalido
#     finisce li'), righe malformate, rientri, radici = svuotate + conservate, vcpuid della
#     struttura = vcpuid della sonda, invept2 coerente, contatori per vCPU non negativi,
#     svuotate prima della scansione senza letture, h1 multiplo di ntr SOLO dove il sorgente
#     lo garantisce, e la CHIUSURA sui contatori globali G1-G0.
#   BORDI (#93 §4 politica 2, #94 §1). Fotografie GT dei contatori lette MENTRE la traccia e'
#     ATTIVA (profile tick-10hz): la finestra va dal primo all'ultimo GT. G0 (BEGIN) e G1 (END)
#     restano solo come ripiego: fuori da ACTIVE DTrace scarta le sonde (dtrace.c:7459), quindi
#     fra G0 e l'attivazione e fra lo spegnimento e G1 ci sono incrementi SENZA record.
#     Ogni contatore ha un REGISTRO (unita', massimo per operazione dal sorgente, registro()):
#     operazione tutta dentro = esatta dai record; a cavallo di un GT (margine 100 us) = da 0 al
#     suo totale esatto; ORPH valida e operazione aperta = da 0 al massimo per operazione.
#     Etichette BOUND_EXACT / BOUND_COMPATIBLE / BOUND_NOT_PROVEN / FAIL. Le operazioni di
#     bordo si IDENTIFICANO dai record:
#       inizio: ORPH (ritorno senza ingresso) che precede il primo ingresso del suo thread,
#               al piu' una per thread; KORPH (veptkeep senza ingresso) dello stesso thread
#               prima della sua ORPH, al piu' VEPT_NROOTS = 4. Altrove: ERRORE.
#       fine:   operazioni aperte = ingressi (nb) - ritorni (no), al piu' una per vCPU.
#     Ognuna contribuisce ai contatori fra 0 e un tetto dal sorgente (radici <= 4 per
#     operazione, letture <= (retries+1) x 2 x VEPT_OBS_MAX per radice): il contatore deve
#     cadere nell'INTERVALLO, altrimenti INCOMPLETA. Senza operazioni a cavallo l'intervallo
#     e' un punto (chiusura esatta).
#   DERIVAZIONE dei tentativi (#93 §3), separata dalla completezza:
#     EXACT              fb in {0, RACE, VERIFY}: ogni passata 1 e' completa (la race si vede
#                        nella passata 2, la verifica dopo il successo): h1 = a x ntr;
#     DERIVED_CONDITIONAL altri motivi con h1 non multiplo: ceil(h1/ntr), ipotesi = ogni
#                        tentativo legge almeno una tabella e ntr stabile (vero nel sorgente,
#                        non dimostrabile dalla traccia), corroborato dalla chiusura su rd;
#     ATTEMPTS_NOT_PROVEN altri motivi con h1 multiplo (l'ultimo tentativo potrebbe non aver
#                        letto nulla), ntr saturato, h1 = 0: intervallo [lo, hi];
#     NO_TRACKED_TABLES  ntr = 0 (nessuna divisione; se conservata, 1 tentativo per sorgente);
#     NO_SCAN            svuotata prima della scansione (OVERFL, NOKEEP, NOMEM, FORCE).
#   GRUPPI (#93 §5): chiave PRIMARIA pid + EPTP12 COMPLETO; SECONDARIA pid + base (bit
#     51:12), riportata a parte; vCPU diversi; finestra ANCORATA al primo membro (primo-ultimo
#     <= W); W = 1 e 5 ms. Classi: nc=0, nc>0, FULL, MISTO.
#   ESTREMI: SOLO nel modello ipotetico (equivalenza, una scansione sopravvive, coordinamento
#     gratuito): S - max(ti) <= risparmio <= S - min(ti). Il risparmio certificato e' zero.
#   PERTURBAZIONE: confronto descrittivo con il braccio A reale; un allarme rende la misura
#     PERTURBATION_SUSPECTED (sessioni non alternate: la causa non si separa).
#
# Uso:
#   dedup92_an.py --traccia T.txt [--err T.err] [--nvcpu 8] [--retries 1]
#   dedup92_an.py --braccio DIR [--base DIR_A]   (lat-04/lat-05 del braccio)
# Uscita: 0 traccia COMPLETA, 3 INCOMPLETA, 2 uso.
import argparse, math, os, re, sys
from collections import Counter, defaultdict

BASE_MASK = 0x000ffffffffff000
NROOTS = 4		# VEPT_NROOTS, vmx_nested.h:449
OBS_MAX = 2048		# VEPT_OBS_MAX, vmx_vept.c:263 (ntr non puo' saturare a 0xffff)
FB = [(0x01, 'AMBIG'), (0x02, 'L3'), (0x04, 'OVERFL'), (0x08, 'UNREAD'), (0x10, 'WALK'),
	(0x20, 'NRNG'), (0x40, 'RACE'), (0x80, 'NOKEEP'), (0x100, 'NOMEM'), (0x200, 'FORCE'),
	(0x400, 'VERIFY')]
FB_PRIMA = 0x04 | 0x80 | 0x100 | 0x200	# svuotata PRIMA di leggere (nessuna lettura)
FB_ESATTO = (0, 0x40, 0x400)		# passata 1 sempre completa
G_NOMI = ['ops_s', 'ops_a', 'rm', 'rk', 'rf', 'part', 'full', 'race', 'rd', 'ok0', 'ok1', 'ok2',
	'esaur', 'budget', 'nonrace', 'bytes', 'tscan', 'tpart', 'tfull', 'tver']
CAMPI = {
	'R': ['tid', 't0', 'k', 'vc', 'e', 'live', 'inv', 'nr', 'nc', 'fb', 'ntr', 'ns', 't', 'vt',
		'h1', 'h2', 'hr', 'hn'],
	'O': ['tid', 'pid', 'cpu', 'vc', 'ty', 'e', 't0', 't1', 'v0', 'sv', 'off', 'offt', 'nk', 'w',
		'kept', 'nw', 'wt', 'wv', 'h1', 'h2', 'hr', 'hn', 'rh1', 'rh2', 'rhr', 'rhn', 'vcm'],
	'KORPH': ['tid', 't', 'vc', 'e', 'fb', 'ntr'],
	'ORPH': ['tid', 't', 'w'],
	'NEST': ['tid', 'cpu', 't'],
	'H': ['tid', 't0', 'k', 'p', 'gpa'],		# solo livello 2 (dedup95l2.d)
	'G0': ['t'] + G_NOMI, 'G1': ['t'] + G_NOMI, 'GT': ['t', 'ta'] + G_NOMI,
}
HEXK = {'R': {'e', 'fb'}, 'O': {'e'}, 'KORPH': {'e', 'fb'}, 'H': {'gpa'}}
CLASSI = ('nc=0', 'nc>0', 'FULL', 'MISTO')

def s64(v):
	return v - (1 << 64) if v >= 1 << 63 else v

def fbnomi(fb):
	return '+'.join(n for b, n in FB if fb & b) or '0'

# ------------------------------------------------------------------ lettura
def leggi(testo):
	"""Righe R/O/KORPH/ORPH/NEST/G0/G1 e conteggi a END. Nessuna riga si ricostruisce."""
	P = {t: [] for t in ('R', 'O', 'KORPH', 'ORPH', 'NEST', 'GT', 'H')}
	P.update({'G0': None, 'G1': None, 'malformate': [], 'conta': {}, 'conti': {},
		'pronta': '== LATENZA PRONTA ==' in testo, 'chiusa': '== LATENZA CHIUSA ==' in testo})
	for riga in testo.splitlines():
		tipo, _, resto = riga.partition(' ')
		if tipo not in CAMPI:
			if tipo in ('CONTA', 'CONTI'):
				mm = re.match(r'(\w+)=\s*(-?\d+)\s*$', resto)
				if mm:
					P['conta' if tipo == 'CONTA' else 'conti'][mm.group(1)] = int(mm.group(2))
				else:
					P['malformate'].append(riga)
			continue
		d = {}
		ok = True
		for kv in resto.split():
			k, sep, v = kv.partition('=')
			if not sep:
				ok = False
				break
			try:
				d[k] = int(v, 16) if k in HEXK.get(tipo, ()) else s64(int(v))
			except ValueError:
				ok = False
				break
		if not ok or list(d) != CAMPI[tipo]:
			P['malformate'].append(riga)
			continue
		if tipo in ('G0', 'G1'):
			if P[tipo] is not None:
				P['malformate'].append(riga)	# doppio: file accodato
			P[tipo] = d
		else:
			P[tipo].append(d)
	return P

# ------------------------------------------------------------------ tentativi
def tentativi(r, retries):
	"""(lo, hi, etichetta): numero di tentativi della radice, intervallo se non dimostrato."""
	fb, ntr, h1 = r['fb'], r['ntr'], r['h1']
	if fb & FB_PRIMA:
		return 0, 0, 'NO_SCAN'
	if ntr == 0:
		return (1, 1, 'NO_TRACKED_TABLES') if fb == 0 else (1, retries + 1, 'NO_TRACKED_TABLES')
	if ntr >= 0xffff or h1 <= 0:
		return 1, retries + 1, 'ATTEMPTS_NOT_PROVEN'
	if fb in FB_ESATTO:
		if h1 % ntr == 0:
			return h1 // ntr, h1 // ntr, 'EXACT'
		return 1, retries + 1, 'INCOERENTE'	# il sorgente lo esclude: errore d'integrita'
	if h1 % ntr:
		a = -(-h1 // ntr)
		return a, a, 'DERIVED_CONDITIONAL'
	return h1 // ntr, min(h1 // ntr + 1, retries + 1), 'ATTEMPTS_NOT_PROVEN'

# ------------------------------------------------------------------ registro dei contatori (#94 §1)
# (contatore, unita', massimo per OPERAZIONE dal sorgente di 27125f004917). Tutti si incrementano
# DENTRO vmx_vept_invept (fra ingresso e ritorno): un'operazione tutta interna alla finestra
# contribuisce esattamente cio' che dicono i suoi record. None = non chiudibile dai record.
def registro(retries):
	r4 = NROOTS
	return [
		('ops_s', 'operazioni single-context', 1), ('ops_a', 'operazioni all-context', 1),
		('rm', 'radici colpite', r4), ('rk', 'radici conservate', r4), ('rf', 'radici svuotate', r4),
		('part', 'conservate (B1)', r4), ('full', 'svuotate (B1)', r4), ('race', 'svuotate per race', r4),
		('rd', 'ritentativi avviati', r4 * retries),
		('ok0', 'riuscite al tentativo 1', r4), ('ok1', 'riuscite al tentativo 2', r4), ('ok2', 'riuscite al tentativo 3', r4),
		('esaur', 'race dopo un ritentativo', r4), ('budget', 'tagli per budget', r4),
		('nonrace', 'svuotate non-race dopo un ritentativo', r4),
		('bytes', 'byte di EPT12 letti', r4 * (retries + 1) * 2 * OBS_MAX * 4096),
		('tscan', 'ns di scansione', None), ('tpart', 'ns di azzeramento+verifica', None),
		('tfull', 'ns di svuotamento', None), ('tver', 'ns di verifica', None),
	]

def contributo_radice(r, retries):
	"""{contatore: (min, max)} di una radice, dai suoi record; intervallo solo dove il numero
	di tentativi non e' dimostrato. Semantica dal sorgente (vmx_vept.c:1405-1500)."""
	lo, hi, _ = tentativi(r, retries)
	fb = r['fb']
	def rng(f):
		v = [f(a) for a in range(lo, hi + 1)]
		return min(v), max(v)
	k = (1, 1) if fb == 0 else (0, 0)
	w = (0, 0) if fb == 0 else (1, 1)
	c = {'rm': (1, 1), 'rk': k, 'part': k, 'rf': w, 'full': w, 'race': (1, 1) if fb & 0x40 else (0, 0),
		'rd': rng(lambda a: max(a - 1, 0)),
		'esaur': rng(lambda a: int(fb == 0x40 and a >= 2)),
		'budget': rng(lambda a: int(fb == 0x40 and a <= retries)),
		'nonrace': rng(lambda a: int(fb not in FB_ESATTO and not fb & FB_PRIMA and a >= 2))}
	for i in (1, 2, 3):	# ok* contano anche VERIFY: si incrementano PRIMA della verifica
		c['ok%d' % (i - 1)] = rng(lambda a, i=i: int(fb in (0, 0x400) and a == i))
	b = (r['h1'] + r['h2'] - r['hn']) * 4096
	c['bytes'] = (b, b)
	return c

MARGINE = 100000	# ns: scarto fra CPU attorno all'INTERVALLO di lettura [t, ta] di un GT
LARGHEZZA_MAX = 1000000	# ns: un GT letto in piu' di 1 ms non delimita: BOUND_NOT_PROVEN (#95 §2)

def finestra(P):
	"""(G_inizio, G_fine, modo). GT: letti con la traccia ATTIVA (modo 'GT'). Senza GT,
	G0/G1 di BEGIN/END (modo 'BEGIN_END'): fessure WARMUP/DRAINING senza record, quindi un
	contatore OLTRE il massimo non e' un errore dimostrato ma NON certificato."""
	if len(P['GT']) >= 2:
		g = sorted(P['GT'], key=lambda x: x['t'])
		return g[0], g[-1], 'GT'	# GT ha t (prima delle letture) e ta (dopo)
	if P['G0'] and P['G1']:
		return P['G0'], P['G1'], 'BEGIN_END'
	return None, None, None

def bilancio(P, retries, nvcpu):
	"""[(contatore, unita', delta, lo, hi, etichetta, dettaglio)] con etichetta BOUND_EXACT,
	BOUND_COMPATIBLE, BOUND_NOT_PROVEN o FAIL."""
	gi, gf, modo = finestra(P)
	if modo is None:
		return []
	REG = registro(retries)
	cap = {k: m for k, _, m in REG}
	lo = dict.fromkeys(cap, 0)
	hi = dict.fromkeys(cap, 0)
	per_op = defaultdict(list)
	for r in P['R']:
		per_op[(r['tid'], r['t0'])].append(r)
	n = Counter()
	for o in P['O']:
		c = {k: (0, 0) for k in cap}
		c['ops_s' if o['ty'] == 1 else 'ops_a'] = (1, 1)
		for r in per_op.get((o['tid'], o['t0']), ()):
			for k, (a, b) in contributo_radice(r, retries).items():
				c[k] = (c[k][0] + a, c[k][1] + b)
		# #95 §2: fuori/dentro rispetto all'INTERVALLO di lettura [t, ta] di ciascun GT
		if modo == 'GT' and (o['t1'] < gi['t'] - MARGINE or o['t0'] > gf['ta'] + MARGINE):
			n['fuori'] += 1
			continue
		dentro = modo != 'GT' or (o['t0'] > gi['ta'] + MARGINE and o['t1'] < gf['t'] - MARGINE)
		n['dentro' if dentro else 'a cavallo'] += 1
		for k in cap:
			if cap[k] is not None:
				lo[k] += c[k][0] if dentro else 0
				hi[k] += c[k][1]
	orph_ok = bordi(P)[0]
	na = max(P['conti'].get('nb', 0) - P['conti'].get('no', 0), 0)
	nbordo = sum(1 for x in orph_ok if modo != 'GT' or x['t'] >= gi['t'] - MARGINE) + na
	larghe = modo == 'GT' and max(gi['ta'] - gi['t'], gf['ta'] - gf['t']) > LARGHEZZA_MAX
	out = []
	for k, unita, m in REG:
		d = gf[k] - gi[k]
		if m is None:
			out.append((k, unita, d, None, None, 'BOUND_NOT_PROVEN', 'non chiudibile dai record (tempo)'))
			continue
		h = hi[k] + m * nbordo
		if larghe:
			et = 'BOUND_NOT_PROVEN'		# GT troppo lento a leggere: non delimita
		elif lo[k] <= d <= h:
			et = 'BOUND_EXACT' if lo[k] == h else 'BOUND_COMPATIBLE'
		elif d > h and modo == 'BEGIN_END':
			et = 'BOUND_NOT_PROVEN'
		else:
			et = 'FAIL'
		out.append((k, unita, d, lo[k], h, et, '%s%s; op dentro %d, a cavallo %d, di bordo %d' % (modo,
			' (letture GT %d/%d ns)' % (gi['ta'] - gi['t'], gf['ta'] - gf['t']) if modo == 'GT' else '', n['dentro'], n['a cavallo'], nbordo)))
	return out

# ------------------------------------------------------------------ bordi
def bordi(P):
	"""Classifica le orfane: valide solo al bordo d'inizio (vedi testata)."""
	primo = {}
	for o in P['O']:
		primo[o['tid']] = min(primo.get(o['tid'], o['t0']), o['t0'])
	orph_ok, orph_ko, visti = [], [], set()
	for x in sorted(P['ORPH'], key=lambda x: x['t']):
		if x['tid'] in visti or x['t'] >= primo.get(x['tid'], float('inf')):
			orph_ko.append(x)
		else:
			visti.add(x['tid'])
			orph_ok.append(x)
	t_orph = {x['tid']: x['t'] for x in orph_ok}
	k_ok, k_ko, n = [], [], Counter()
	for x in sorted(P['KORPH'], key=lambda x: x['t']):
		n[x['tid']] += 1
		if x['tid'] in t_orph and x['t'] <= t_orph[x['tid']] and n[x['tid']] <= NROOTS:
			k_ok.append(x)
		else:
			k_ko.append(x)
	return orph_ok, orph_ko, k_ok, k_ko

# ------------------------------------------------------------------ integrita'
retries_glob, nvcpu_glob = [1], [8]

def integrita(P, err, nvcpu, retries):
	retries_glob[0], nvcpu_glob[0] = retries, nvcpu
	C = []
	def c(nome, ok, det=''):
		C.append((nome, bool(ok), det))
	R, O = P['R'], P['O']
	ct, ci = P['conta'], P['conti']
	c('traccia aperta e chiusa (marcatori)', P['pronta'] and P['chiusa'])
	c('stderr di DTrace vuoto (drop, errori di indirizzo)', err.strip() == '', err.strip()[:120])
	c('righe malformate = 0', not P['malformate'], len(P['malformate']))
	if P['GT']:
		w = sorted(x['ta'] - x['t'] for x in P['GT'])
		c('intervallo di lettura dei GT: 0 <= ta - t <= 1 ms', w[0] >= 0 and w[-1] <= LARGHEZZA_MAX,
			'p50 %d ns, max %d ns su %d GT' % (w[len(w) // 2], w[-1], len(w)))
	c('fotografie dei contatori: GT >= 2 (o G0 e G1)', len(P['GT']) >= 2 or (P['G0'] is not None and P['G1'] is not None),
		'GT %d, G0 %s, G1 %s' % (len(P['GT']), P['G0'] is not None, P['G1'] is not None))
	c('righe O = CONTI no', len(O) == ci.get('no', 0), '%d / %d' % (len(O), ci.get('no', 0)))
	c('righe R = CONTI nr', len(R) == ci.get('nr', 0), '%d / %d' % (len(R), ci.get('nr', 0)))
	c('righe ORPH/KORPH = CONTI', len(P['ORPH']) == ci.get('orph', 0) and len(P['KORPH']) == ci.get('korph', 0))
	c('n delle latenze = righe O', ct.get('n', 0) == len(O), '%d / %d' % (ct.get('n', 0), len(O)))
	c('rientri = 0', ct.get('annidate', 0) == 0 and not P['NEST'], ct.get('annidate', 0))
	orph_ok, orph_ko, k_ok, k_ko = bordi(P)
	c('ritorni orfani solo al bordo d\'inizio (<= 1 per thread)', not orph_ko and len(orph_ok) <= nvcpu,
		'%d validi, %d fuori bordo' % (len(orph_ok), len(orph_ko)))
	c('veptkeep orfane solo al bordo d\'inizio (prima della ORPH)', not k_ko, '%d validi, %d fuori bordo' % (len(k_ok), len(k_ko)))
	aperte = ci.get('nb', 0) - ci.get('no', 0)
	c('operazioni aperte alla fine: 0 <= nb - no <= vCPU', 0 <= aperte <= nvcpu, aperte)
	c('veptkeep di altri processi = 0', ci.get('kaltri', 0) == 0, ci.get('kaltri', 0))
	per_op = Counter((r['tid'], r['t0']) for r in R)
	ochiavi = {(o['tid'], o['t0']) for o in O}
	ultimo = {}
	for o in O:
		ultimo[o['tid']] = max(ultimo.get(o['tid'], o['t0']), o['t0'])
	sciolte = {k for k in per_op if k not in ochiavi}
	ok_sc = len(sciolte) <= max(aperte, 0) and all(k[1] > ultimo.get(k[0], -1) for k in sciolte)
	c('R senza O solo nelle operazioni aperte alla fine', ok_sc, len(sciolte))
	bad = sum(1 for o in O if o['nk'] != per_op.get((o['tid'], o['t0']), 0) or o['nk'] != o['w'] + o['kept'])
	c('radici = svuotate + conservate (per operazione)', bad == 0 and ci.get('wkmis', 0) == 0,
		'%d op, wkmis %d' % (bad, ci.get('wkmis', 0)))
	c('vcpuid struttura = vcpuid sonda (offset +0x2c0)', ci.get('vcmis', 0) == 0 and all(o['vcm'] == 0 for o in O), ci.get('vcmis', 0))
	c('invept2 coerente col ritorno (puntatore kept)', ci.get('inv2mis', 0) == 0, ci.get('inv2mis', 0))
	ntid = len({o['tid'] for o in O})
	d_inv = len(O) - ci.get('inv2', 0) - ci.get('inv2miss', 0)
	c('invept2 mai mancante prima dell\'operazione successiva del thread', ci.get('inv2miss', 0) == 0, ci.get('inv2miss', 0))
	c('invept2 al bordo: 0 <= op - inv2 <= thread; orfane in [ORPH, ORPH + vCPU]',
		0 <= d_inv <= ntid and len(orph_ok) <= ci.get('inv2orph', 0) <= len(orph_ok) + nvcpu,
		'op-inv2 %d, inv2orph %d' % (d_inv, ci.get('inv2orph', 0)))
	neg = sum(1 for x in R + O for h in ('h1', 'h2', 'hr', 'hn') if x[h] < 0)
	c('contatori per vCPU non negativi (nessun flush dentro)', neg == 0, neg)
	c('riuso fra le passate = 0 (vept_scan_hold_keep=0)', all(x['hr'] == 0 for x in R), sum(x['hr'] for x in R))
	resid = sum(1 for o in O if o['rh1'] or o['rh2'] or o['rhr'] or o['rhn'])
	c('letture fuori dalle radici = 0', resid == 0, resid)
	pre = sum(1 for r in R if r['fb'] & FB_PRIMA and (r['h1'] or r['h2']))
	c('svuotate prima della scansione: nessuna lettura', pre == 0, pre)
	T = [tentativi(r, retries) for r in R]
	inc = sum(1 for t in T if t[2] == 'INCOERENTE') + sum(1 for r in R if r['fb'] in FB_ESATTO and r['h2'] > r['h1'])
	c('fb in {0,RACE,VERIFY}: h1 multiplo di ntr, h2 <= h1', inc == 0, inc)
	oltre = sum(1 for t in T if t[0] > retries + 1)
	c('tentativi <= retries + 1', oltre == 0, '%d (retries %d)' % (oltre, retries))
	for k, unita, d, lo, hi, et, det in bilancio(P, retries, nvcpu):
		if et == 'BOUND_NOT_PROVEN' and lo is None:
			continue		# contatori di tempo: si stampano nel registro, non si chiudono
		c('chiusura %s (%s)' % (k, unita), et in ('BOUND_EXACT', 'BOUND_COMPATIBLE'),
			'%s: %d in [%d, %d]; %s' % (et, d, lo, hi, det))
	return C

# ------------------------------------------------------------------ analisi
def q(v, p):
	if not v:
		return float('nan')
	v = sorted(v)
	return v[min(len(v) - 1, int(math.ceil(p / 100 * len(v))) - 1)]

def servizio_radici(R, O):
	"""Servizio (vtimestamp) per radice: dall'ingresso o dalla radice precedente della
	stessa operazione (include lo svuotamento della radice precedente). Solo radici di
	operazioni con record O (denominatore stabile, #93 §6)."""
	v0 = {(o['tid'], o['t0']): o['v0'] for o in O}
	per = defaultdict(list)
	for r in R:
		per[(r['tid'], r['t0'])].append(r)
	sr = {}
	for k, rr in per.items():
		if k not in v0:
			continue
		prev = v0[k]
		for r in sorted(rr, key=lambda x: x['k']):
			sr[id(r)] = r['vt'] - prev
			prev = r['vt']
	return sr

def chiave_completa(r):
	return r['e']

def chiave_base(r):
	return r['e'] & BASE_MASK

def gruppi(R, O, W, chiave=chiave_completa):
	"""Partizione ANCORATA: il primo membro non assegnato apre il gruppo; entrano i record
	della stessa (pid, chiave) con t0 - t0_ancora <= W e vCPU non ancora presente. Un vCPU
	gia' presente resta fuori e aprira' un gruppo dopo."""
	pidop = {(o['tid'], o['t0']): o for o in O}
	per = defaultdict(list)
	for r in R:
		o = pidop.get((r['tid'], r['t0']))
		if o is not None:
			per[(o['pid'], chiave(r))].append((r['t0'], r, o))
	G = []
	for k, v in per.items():
		v.sort(key=lambda x: (x[0], x[1]['vc'], x[1]['k']))
		preso = [False] * len(v)
		for i in range(len(v)):
			if preso[i]:
				continue
			preso[i] = True
			membri = [v[i]]
			vcs = {v[i][1]['vc']}
			for j in range(i + 1, len(v)):
				if v[j][0] - v[i][0] > W:
					break
				if preso[j] or v[j][1]['vc'] in vcs:
					continue
				preso[j] = True
				membri.append(v[j])
				vcs.add(v[j][1]['vc'])
			G.append((k, membri))
	return G

def classe(rr):
	nf = sum(1 for r in rr if r['fb'] != 0)
	if nf == len(rr):
		return 'FULL'
	if nf:
		return 'MISTO'
	return 'nc=0' if all(r['nc'] == 0 for r in rr) else 'nc>0'

def statistiche_gruppi(R, O, W, sr, den, chiave):
	ofine = {(o['tid'], o['t0']): o['t1'] for o in O}
	G = gruppi(R, O, W, chiave)
	multi = [g for g in G if len(g[1]) >= 2]
	x = {'gruppi': len(multi), 'singoli': sum(1 for g in G if len(g[1]) == 1),
		'membri': Counter(len(g[1]) for g in multi), 'membri_tot': sum(len(g[1]) for g in multi),
		'sovrapposti': 0, 'servizio': 0, 'ns': 0, 'lo': 0, 'hi': 0, 'spread': [],
		'cm': 0, 'cm_servizio': 0, 'cm_lo': 0, 'cm_hi': 0,
		'classi': {k: [0, 0] for k in CLASSI}, 'cm_classi': {k: [0, 0] for k in CLASSI}}
	for _, m in multi:
		rr = [r for _, r, _ in m]
		t = [sr.get(id(r), 0) for r in rr]
		S = sum(t)
		cl = classe(rr)
		x['classi'][cl][0] += 1
		x['classi'][cl][1] += S
		iv = sorted((r['t0'], ofine[(r['tid'], r['t0'])]) for r in rr)
		x['sovrapposti'] += any(iv[i + 1][0] < iv[i][1] for i in range(len(iv) - 1))
		x['servizio'] += S
		x['ns'] += sum(r['ns'] for r in rr)
		x['lo'] += S - max(t)
		x['hi'] += S - min(t)
		x['spread'].append(max(r['t0'] for r in rr) - min(r['t0'] for r in rr))
		if cl in ('nc=0', 'nc>0') and len({(r['nc'], r['ntr']) for r in rr}) == 1:
			x['cm'] += 1
			x['cm_servizio'] += S
			x['cm_lo'] += S - max(t)
			x['cm_hi'] += S - min(t)
			x['cm_classi'][cl][0] += 1
			x['cm_classi'][cl][1] += S
	x['quota'] = x['servizio'] / den if den else float('nan')
	den_ns = sum(r['ns'] for r in R if id(r) in sr)
	x['quota_elapsed'] = x['ns'] / den_ns if den_ns else float('nan')
	x['quota_cm_nei_gruppi'] = x['cm_servizio'] / x['servizio'] if x['servizio'] else 0.0
	return x

def analizza(P, retries):
	R, O = P['R'], P['O']
	A = {}
	sr = servizio_radici(R, O)
	Rv = [r for r in R if id(r) in sr]		# radici di operazioni complete
	A['op'] = len(O)
	A['radici'] = len(Rv)
	A['radici_aperte'] = len(R) - len(Rv)
	A['servizio_op'] = sum(o['sv'] for o in O)
	A['servizio_radici'] = sum(sr.values())
	A['ns_radici'] = sum(r['ns'] for r in Rv)
	A['svuotamento_v'] = sum(o['wv'] for o in O)
	A['svuotamento_n'] = sum(o['nw'] for o in O)
	A['tipi'] = Counter(o['ty'] for o in O)
	A['radici_per_op'] = Counter(o['nk'] for o in O)
	part = [r for r in Rv if r['fb'] == 0]
	full = [r for r in Rv if r['fb'] != 0]
	A['conservate'], A['svuotate'] = len(part), len(full)
	A['motivi'] = Counter(fbnomi(r['fb']) for r in full)
	A['ntr'] = [r['ntr'] for r in Rv]
	A['nc_part'] = [r['nc'] for r in part]
	T = [tentativi(r, retries) for r in Rv]
	A['derivazione'] = Counter(t[2] for t in T)
	A['tent'] = Counter(t[0] if t[0] == t[1] else '%d..%d' % (t[0], t[1]) for t in T)
	vuote = [r for r in part if r['nc'] == 0]
	A['vuote'] = len(vuote)
	A['vuote_servizio'] = sum(sr[id(r)] for r in vuote)
	A['vuote_ns'] = sum(r['ns'] for r in vuote)
	A['vuote_letture'] = sum(r['h1'] + r['h2'] for r in vuote)
	A['letture'] = sum(r['h1'] + r['h2'] for r in Rv)
	pv = defaultdict(Counter)
	for r in Rv:
		x = pv[r['vc']]
		x['radici'] += 1
		x['conservate'] += r['fb'] == 0
		x['svuotate'] += r['fb'] != 0
		x['race'] += bool(r['fb'] & 0x40)
		x['vuote'] += r['fb'] == 0 and r['nc'] == 0
		x['ntr'] += r['ntr']
		x['letture'] += r['h1'] + r['h2']
		x['servizio'] += sr[id(r)]
		x['vuote_servizio'] += sr[id(r)] if (r['fb'] == 0 and r['nc'] == 0) else 0
	A['per_vcpu'] = dict(sorted(pv.items()))
	gi, gf, _ = finestra(P)
	if gi:
		d = {k: gf[k] - gi[k] for k in G_NOMI}
		tot = d['tscan'] + d['tpart'] + d['tfull']
		A['quota_scansione_globale'] = d['tscan'] / tot if tot else float('nan')
	den = A['servizio_radici']
	A['gruppi'] = {W: statistiche_gruppi(Rv, O, W, sr, den, chiave_completa) for W in (1000000, 5000000)}
	A['gruppi_base'] = {W: statistiche_gruppi(Rv, O, W, sr, den, chiave_base) for W in (1000000, 5000000)}
	return A

# ------------------------------------------------------------------ decisione (#93 §6)
def decisione(A, completa, perturbata):
	"""Regola PRE-REGISTRATA (#93 §6, #94 §6) per PROGETTARE il livello 2 (non una patch).
	Chiave primaria; metrica GROUP_SHARE = root_oncpu_approx (vedi definizioni()). #94 §6:
	nessun veto «nc>0» sulla de-prioritizzazione; NC_POSITIVE_CLUSTER e' solo un'etichetta."""
	if not completa:
		return 'NESSUNA_DECISIONE (traccia INCOMPLETA)'
	g1, g5 = A['gruppi'][1000000], A['gruppi'][5000000]
	if g1['quota'] >= 0.30 and g1['quota_cm_nei_gruppi'] >= 0.50:
		d = 'PROGETTARE_LIVELLO_2'
	elif g1['quota'] < 0.10 and g5['quota'] < 0.10:
		d = 'DEPRIORITIZZARE'
	else:
		d = 'ANALISI_OFFLINE'
	if perturbata:
		d = ('ANALISI_OFFLINE' if d == 'PROGETTARE_LIVELLO_2' else d) + ' PERTURBATION_SUSPECTED'
	return d

def nc_positive_cluster(A):
	"""Etichetta qualitativa separata (#94 §6): a 5 ms i gruppi nc>0 portano >= 50% del
	servizio nei gruppi. Non entra nella decisione."""
	g5 = A['gruppi'][5000000]
	return g5['servizio'] > 0 and g5['classi']['nc>0'][1] / g5['servizio'] >= 0.5

DEFINIZIONI = """GROUP_SHARE_1MS / _5MS = root_oncpu_approx:
  numeratore   = somma, sulle radici dei gruppi fra VP (chiave primaria, finestra ancorata), del
                 servizio ON-CPU della radice = vtimestamp alla sua veptkeep - vtimestamp al punto
                 precedente della stessa operazione (ingresso, o veptkeep della radice prima);
  denominatore = la stessa grandezza su TUTTE le radici di operazioni complete della fase.
  Include: scansione (tutti i tentativi) + azzeramento + verifica per le conservate; per le
  svuotate solo la scansione (lo svuotamento viene dopo la sonda); con piu' radici, lo
  svuotamento della precedente. Esclude il tempo fuori CPU e (d(7)) quello delle sonde.
  Stesso tipo (on-CPU) delle percentuali dell'ABBA (vtimestamp del gestore).
root_elapsed_approx (solo descrittiva): come sopra ma con ns della veptkeep (sbinuptime, tempo
  REALE composito dall'inizio della radice), numeratore e denominatore entrambi elapsed.
Sono quote di lavoro strumentato compatibile con i gruppi, NON scansioni deduplicabili."""

# ------------------------------------------------------------------ perturbazione
SOGLIE = {'servizio_media': 0.10, 'servizio_p99': 0.15, 'race_per_1000': 0.25, 'full_per_1000': 0.25,
	'compilazione_s': 0.10}

def perturbazione(misura, base, soglie=SOGLIE):
	"""[(chiave, base, misura, variazione relativa, allarme)]; valori mancanti saltati.
	Un allarme NON attribuisce la causa: sessioni non alternate."""
	out = []
	for k, s in soglie.items():
		b, m = base.get(k), misura.get(k)
		if b is None or m is None or b != b or m != m or b == 0:
			continue
		v = (m - b) / b
		out.append((k, b, m, v, abs(v) > s))
	return out

def misure_perturbazione(P, lat, comp_s=None):
	d = {k: P['G1'][k] - P['G0'][k] for k in G_NOMI} if P['G0'] and P['G1'] else None
	m = {}
	if lat:
		m['servizio_media'] = lat.get('servizio_media')
		m['servizio_p99'] = lat.get('servizio_p99')
	if d:
		ops = d['ops_s'] + d['ops_a']
		if ops:
			m['race_per_1000'] = 1000 * d['race'] / ops
			m['full_per_1000'] = 1000 * d['full'] / ops
	if comp_s:
		m['compilazione_s'] = comp_s
	return m

# ------------------------------------------------------------------ stampa
def pct(x):
	return '%.1f%%' % (100 * x) if x == x else 'n/d'

def stampa_gruppi(nome, x, den_op):
	print('-- %s: gruppi fra VP %d, singoli %d, membri %s' % (nome, x['gruppi'], x['singoli'], dict(sorted(x['membri'].items()))))
	print('   per classe (gruppi, servizio s): %s' % ', '.join('%s %d/%.3f' % (k, v[0], v[1] / 1e9) for k, v in x['classi'].items()))
	print('   sovrapposti nel tempo %d; ampiezza p50/max %.3f/%.3f ms' % (x['sovrapposti'],
		q(x['spread'], 50) / 1e6 if x['spread'] else float('nan'), max(x['spread'] or [0]) / 1e6))
	print('   GROUP_SHARE root_oncpu_approx = %s (%.3f s); sulla CPU totale del gestore %s; root_elapsed_approx = %s (%.3f s)'
		% (pct(x['quota']), x['servizio'] / 1e9, pct(x['servizio'] / den_op if den_op else float('nan')), pct(x['quota_elapsed']), x['ns'] / 1e9))
	print('   MODELLO IPOTETICO (equivalenza non dimostrata, coordinamento gratuito): %.3f s <= risparmio <= %.3f s; certificato: 0'
		% (x['lo'] / 1e9, x['hi'] / 1e9))
	print('   COUNTERS_MATCH -> CANDIDATE (filtro DEBOLE): %d gruppi (nc=0 %d, nc>0 %d), servizio %.3f s = %s del servizio nei gruppi'
		% (x['cm'], x['cm_classi']['nc=0'][0], x['cm_classi']['nc>0'][0], x['cm_servizio'] / 1e9, pct(x['quota_cm_nei_gruppi'])))

def stampa(P, A, C, nome, perturbata=False):
	print('== %s' % nome)
	ko = [x for x in C if not x[1]]
	for n, ok, det in C:
		print('  %-58s %-7s %s' % (n, 'ok' if ok else 'ERRATO', det))
	print('-- registro dei 20 contatori (#94 §1): contatore, unita\', delta, intervallo, etichetta')
	for k, unita, d, lo, hi, et, det in bilancio(P, retries_glob[0], nvcpu_glob[0]):
		print('   %-8s %-38s %16d  %s  %s' % (k, unita, d, '[%d, %d]' % (lo, hi) if lo is not None else '-', et))
	print('COMPLETEZZA=%s' % ('PASS' if not ko else 'FAIL (%d controlli)' % len(ko)))
	if ko:
		print('  Traccia INCOMPLETA: nessun dato si promuove; le grandezze sotto sono solo indicative.')
	print('DERIVAZIONE dei tentativi: %s' % dict(A['derivazione']))
	print('-- operazioni %d (tipi %s), radici %d (+%d di operazioni aperte, escluse), per operazione %s, conservate %d, svuotate %d'
		% (A['op'], dict(A['tipi']), A['radici'], A['radici_aperte'], dict(A['radici_per_op']), A['conservate'], A['svuotate']))
	print('   motivi FULL: %s' % dict(A['motivi'].most_common()))
	print('   tentativi: %s' % dict(sorted(A['tent'].items(), key=lambda x: str(x[0]))))
	print('   ntr p50/p95/max: %s/%s/%s; nc (conservate) p50/p95/max: %s/%s/%s'
		% (q(A['ntr'], 50), q(A['ntr'], 95), max(A['ntr'] or [0]), q(A['nc_part'], 50), q(A['nc_part'], 95), max(A['nc_part'] or [0])))
	print('   letture di pagine EPT12 (h1+h2): %d (%.0f per radice)' % (A['letture'], A['letture'] / max(A['radici'], 1)))
	print('-- servizio del GESTORE (vtimestamp): operazioni %.3f s, radici %.3f s; ns delle radici %.3f s; svuotamenti %d, %.3f s'
		% (A['servizio_op'] / 1e9, A['servizio_radici'] / 1e9, A['ns_radici'] / 1e9, A['svuotamento_n'], A['svuotamento_v'] / 1e9))
	if 'quota_scansione_globale' in A:
		print('   quota di SOLA scansione fra le tre componenti del modulo (scan / scan+partial+full): %s' % pct(A['quota_scansione_globale']))
	print('-- conservate con nc = 0: %d su %d (%s); servizio %.3f s (%s del servizio delle radici); letture %d (%s)'
		% (A['vuote'], A['conservate'], pct(A['vuote'] / max(A['conservate'], 1)), A['vuote_servizio'] / 1e9,
		pct(A['vuote_servizio'] / max(A['servizio_radici'], 1)), A['vuote_letture'], pct(A['vuote_letture'] / max(A['letture'], 1))))
	print('   (tetto DESCRITTIVO del costo di quel sottoinsieme; non autorizza a saltare scansioni: #92 §3.1, #93 §6)')
	print('-- per vCPU: radici / conservate / svuotate / race / nc=0 / ntr medio / letture / servizio s / servizio nc=0 s')
	for vc, x in A['per_vcpu'].items():
		print('   vCPU %2d: %7d %7d %6d %6d %7d %7.1f %10d %8.3f %8.3f' % (vc, x['radici'], x['conservate'], x['svuotate'],
			x['race'], x['vuote'], x['ntr'] / max(x['radici'], 1), x['letture'], x['servizio'] / 1e9, x['vuote_servizio'] / 1e9))
	for W in (1000000, 5000000):
		stampa_gruppi('GROUP_SAME_EPTP12 PRIMARIO (EPTP12 completo), %g ms ancorata, IDENTITY_UNPROVEN' % (W / 1e6), A['gruppi'][W], A['servizio_op'])
		b = A['gruppi_base'][W]
		p = A['gruppi'][W]
		print('   SECONDARIO (sola base, a parte): gruppi %d (primario %d), membri %d (%+d), quota %s (%+.1f punti)'
			% (b['gruppi'], p['gruppi'], b['membri_tot'], b['membri_tot'] - p['membri_tot'], pct(b['quota']),
			100 * (b['quota'] - p['quota']) if b['quota'] == b['quota'] and p['quota'] == p['quota'] else float('nan')))
	print('-- definizioni delle metriche')
	print('\n'.join('   ' + x for x in DEFINIZIONI.splitlines()))
	print('NC_POSITIVE_CLUSTER=%s (solo informativo, #94 §6)' % ('si' if nc_positive_cluster(A) else 'no'))
	print('DECISIONE_PREREGISTRATA=%s' % decisione(A, not ko, perturbata))
	return not ko

def carica_lat(path):
	import importlib.util
	spec = importlib.util.spec_from_file_location('an', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'abba_retry_an.py'))
	an = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(an)
	return an.latenze(open(path, errors='replace').read())

def comp_secondi(d):
	try:
		m = re.search(r'^real\s+(\d+)m([\d.]+)s', open(os.path.join(d, 'kbuild.log'), errors='replace').read(), re.M)
		return int(m.group(1)) * 60 + float(m.group(2)) if m else None
	except FileNotFoundError:
		return None

def base_A(d):
	"""Il braccio A gia' registrato: latenze della compilazione e delta dei contatori
	05-inizio -> 05-fine dalle foto."""
	sub = os.path.join(d, '1-A') if os.path.isdir(os.path.join(d, '1-A')) else d
	lat = carica_lat(os.path.join(sub, 'lat-05.txt'))
	F = {}
	cur = None
	for riga in open(os.path.join(sub, 'foto.txt'), errors='replace'):
		if riga.startswith('FOTO '):
			cur = riga.split()[1]
			F[cur] = {}
		elif cur and riga.startswith('hw.vmm.vmx.'):
			k, _, v = riga[len('hw.vmm.vmx.'):].partition(':')
			try:
				F[cur][k] = int(v)
			except ValueError:
				pass
	a, b = F.get('05-inizio', {}), F.get('05-fine', {})
	g = lambda k: b.get(k, 0) - a.get(k, 0)
	ops = g('vept_invept_single') + g('vept_invept_all')
	m = {'servizio_media': lat.get('servizio_media') if lat else None, 'servizio_p99': lat.get('servizio_p99') if lat else None,
		'compilazione_s': comp_secondi(sub)}
	if ops:
		m['race_per_1000'] = 1000 * g('vept_keep_scan_race_fallbacks') / ops
		m['full_per_1000'] = 1000 * g('vept_keep_full_fallbacks') / ops
	return m

def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('--traccia')
	ap.add_argument('--err')
	ap.add_argument('--braccio')
	ap.add_argument('--base')
	ap.add_argument('--nvcpu', type=int, default=8)
	ap.add_argument('--retries', type=int, default=1)
	a = ap.parse_args()
	tutto_ok = True
	if a.traccia:
		P = leggi(open(a.traccia, errors='replace').read())
		err = open(a.err).read() if a.err else ''
		C = integrita(P, err, a.nvcpu, a.retries)
		tutto_ok = stampa(P, analizza(P, a.retries), C, a.traccia)
	elif a.braccio:
		for fase in ('04', '05'):
			t = os.path.join(a.braccio, 'lat-%s.txt' % fase)
			if not os.path.exists(t):
				print('== %s: assente' % t)
				tutto_ok = False
				continue
			P = leggi(open(t, errors='replace').read())
			err = open(os.path.join(a.braccio, 'lat-%s.err' % fase)).read()
			C = integrita(P, err, a.nvcpu, a.retries)
			pert = False
			if fase == '05' and a.base:
				m = misure_perturbazione(P, carica_lat(t), comp_secondi(a.braccio))
				print('-- PERTURBAZIONE (descrittiva; sessioni NON alternate: deriva e sonde non separabili)')
				for k, b, v, rel, allarme in perturbazione(m, base_A(a.base)):
					pert |= allarme
					print('   %-16s A %12.4g  misura %12.4g  %+6.1f%%  %s' % (k, b, v, 100 * rel, 'ALLARME' if allarme else ''))
				print('PERTURBAZIONE=%s' % ('PERTURBATION_SUSPECTED' if pert else 'nessun allarme'))
			tutto_ok &= stampa(P, analizza(P, a.retries), C, t, pert)
	else:
		ap.print_usage()
		sys.exit(2)
	sys.exit(0 if tutto_ok else 3)

if __name__ == '__main__':
	main()
