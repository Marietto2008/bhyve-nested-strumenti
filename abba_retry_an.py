#!/usr/local/bin/python3
# abba_retry_an.py -- Claude 27/10/2026, parere #85 §3: analisi dell'ABBA a 2 VP
# retry 1 (A) contro retry 2 (B), ordine A1 B1 B2 A2 (run-abba-retry-2vp.sh).
# Derivato da abba_an.py (letture di foto.txt, ext4 e compilazione). Per ogni
# braccio e per fase (Windows fermo, ext4, compilazione, tutta la prova):
#   - tempo reale delle fasi (fasi.txt) e unita' di lavoro (cicli ext4,
#     compilazione con rc);
#   - DELTA dei contatori (EPT02, foglie per motivo, partial/full, retry,
#     uscite, INVEPT) assoluti e per unita' di lavoro;
#   - latenza del gestore INVEPT (lat-04/lat-05 di abba-invept-lat.d):
#     n, medie, p50/p95/p99/p99.9 (risoluzione del bucket llquantize), massimo,
#     oltre 2 e 16 ms, separando servizio (su CPU) e reale (con fuori CPU);
#   - controlli di correttezza e di configurazione per braccio.
# Confronto: A1 B1 B2 A2, Amean, Bmean, delta % = 100*(Bmean/Amean-1), e le
# due coppie (B1 contro A1, B2 contro A2): stesso segno = COERENTE, altrimenti
# CONTRADDITTORIO. Verdetto sulle prestazioni: MIGLIORA / PEGGIORA solo se la
# compilazione va nello stesso senso nelle due coppie, altrimenti INCONCLUSIVE.
# Metriche non disponibili: dichiarate, mai inventate.
# Uso: abba_retry_an.py <cartella> [--mappa N=A,T=B] [--retry A=1,B=2]
#      abba_retry_an.py --lat <file lat> (solo la latenza, per i collaudi)
import glob, os, re, sys, statistics as st
from collections import defaultdict

NAN = float('nan')

def leggi_foto(path):
	foto, cur = {}, None
	for l in open(path, errors='replace'):
		m = re.match(r'FOTO (\S+) ([\d.]+)', l)
		if m:
			cur = m.group(1)
			foto[cur] = {'t': float(m.group(2)), 's': defaultdict(int), 'cpu': 0.0}
			continue
		if cur is None:
			continue
		m = re.match(r'hw\.vmm\.vmx\.(\S+): (\d+)$', l.strip())
		if m:
			foto[cur]['s']['x:' + m.group(1)] = int(m.group(2)); continue
		m = re.match(r'\s*\d+\s+(\d+):([\d.]+)\s+bhyve/vcpu (\d+)', l)
		if m:
			foto[cur]['cpu'] += int(m.group(1)) * 60 + float(m.group(2)); continue
		m = re.match(r'(.*\S)\s+(\d+)$', l.rstrip('\n'))
		if m and not re.match(r'vcpu\d+ stats', l):
			foto[cur]['s'][m.group(1).strip()] += int(m.group(2))
	return foto

# contatori (chiave in foto, nome breve)
CTR = [('total number of vm exits', 'uscite'),
	('x:nested_ept02_faults_l0', 'ept02_fault'), ('x:vst_fault', 'vst_fault'),
	('x:vept_keep_partial_invepts', 'partial'), ('x:vept_keep_full_fallbacks', 'full'),
	('x:vept_keep_scan_race_fallbacks', 'full_race'),
	('x:vept_keep_invalidated_leaves', 'foglie_invalidate'), ('x:vept_keep_retained_leaves', 'foglie_conservate'),
	('x:vept_scan_first_pass_ok', 'ok_1o'), ('x:vept_scan_retry_1_success', 'retry_1_success'),
	('x:vept_scan_retry_2_success', 'retry_2_success'), ('x:vept_scan_retries_done', 'retries_done'),
	('x:vept_scan_retry_exhausted', 'retry_exhausted'), ('x:vept_scan_retry_budget_fallback', 'retry_budget'),
	('x:vept_scan_retry_nonrace_fallback', 'retry_nonrace'),
	('x:vept_retry_1_leaves_saved', 'foglie_salvate_r1'), ('x:vept_retry_2_leaves_saved', 'foglie_salvate_r2'),
	('x:nested_invept_ns_sum', 'invept_ns_somma'), ('x:vept_invept_single', 'invept_single'),
	('x:vept_invept_all', 'invept_all'), ('x:vept_keep_verify_mismatch', 'mismatch'),
	('x:nested_sh_faults', 'errori_shadow'), ('x:vpid02_off_vcpus', 'vpid02_off'),
	('x:vpid02_invvpid_novpid12', 'invvpid02_novpid12'), ('x:vpid02_invvpid_novpid12_slow', 'invvpid02_lento')]

def zapped(F):
	return sorted({k[2:] for f in F.values() for k in f['s'] if k.startswith('x:vept_leaves_zapped_')})

def delta(F, a, b, extra=()):
	if a not in F or b not in F:
		return None
	A, B = F[a], F[b]
	r = {n: B['s'][k] - A['s'][k] for k, n in CTR}
	for z in extra:
		r[z] = B['s']['x:' + z] - A['s']['x:' + z]
	r['dt'] = B['t'] - A['t']
	r['cpu_vcpu_s'] = B['cpu'] - A['cpu']
	return r

def fasi(path):
	try:
		ev = [(m.group(1), float(m.group(2))) for m in
		    (re.match(r'FASE (\S+) ([\d.]+)', l) for l in open(path)) if m]
	except FileNotFoundError:
		return {}
	return {ev[i][0]: ev[i + 1][1] - ev[i][1] for i in range(len(ev) - 1)}

def ext4(d):
	try:
		ev = [(m.group(1), m.group(2)) for m in
		    (re.match(r'CICLO (\S+) (\S+) ([\d.]+)', l) for l in open(d + '/gapmem-A.log')) if m]
	except FileNotFoundError:
		return NAN, NAN
	return (sum(1 for c, p in ev if p == 'ok' and not c.startswith('R')),
	    sum(1 for c, p in ev if p == 'ERRORE'))

def compil(d):
	try:
		t = open(d + '/kbuild.log', errors='replace').read()
	except FileNotFoundError:
		return NAN, '?'
	m = re.search(r'^real\s+(\d+)m([\d.]+)s', t, re.M)
	rc = re.search(r'kernel rc=(\d+)', t)
	return (int(m.group(1)) * 60 + float(m.group(2)) if m else NAN), (rc.group(1) if rc else '?')

# ---------------------------------------------------------------- latenza
def latenze(testo):
	"""Da abba-invept-lat.d: conteggi, istogrammi, percentili (limite inferiore
	del bucket in cui cade il percentile). None se il file manca o e' aperto."""
	if '== LATENZA CHIUSA ==' not in testo:
		return None
	r = {}
	for k, v in re.findall(r'^CONTA (\w+)=\s*(\d+)', testo, re.M):
		r[k] = int(v)
	for nome in ('reale', 'servizio'):
		m = re.search(r'== ISTOGRAMMA %s ==\n(.*?)(?=== ISTOGRAMMA|== LATENZA CHIUSA)' % nome, testo, re.S)
		tutte = sorted((int(v), int(c)) for v, c in re.findall(r'^\s*(\d+) \|[@ ]*\s(\d+)\s*$', m.group(1) if m else '', re.M))
		tot = sum(c for _, c in tutte)
		r[nome + '_n'] = tot
		for q in (50, 95, 99, 99.9):
			s, v, hi = 0, NAN, NAN
			for i, (val, c) in enumerate(tutte):
				s += c
				if c and s >= q / 100 * tot:
					v = val
					hi = tutte[i + 1][0] if i + 1 < len(tutte) else NAN	# bucket [v, hi)
					break
			k = '%s_p%s' % (nome, str(q).replace('.', '_'))
			r[k] = v
			r[k + '_hi'] = hi
	# coerenza: numerosita' degli istogrammi = conteggio delle operazioni
	r['coerente'] = r.get('n', -1) == r.get('reale_n', -2) == r.get('servizio_n', -3)
	# p99.9 con meno di 10 campioni oltre il percentile e' instabile
	r['coda_instabile'] = r.get('n', 0) * 0.001 < 10
	n = r.get('n', 0)
	r['reale_media'] = r.get('reale_somma', 0) / n if n else NAN
	r['servizio_media'] = r.get('servizio_somma', 0) / n if n else NAN
	return r

# ---------------------------------------------------------------- bracci
def braccio(d, mod, R):
	F = leggi_foto(d + '/foto.txt') if os.path.exists(d + '/foto.txt') else {}
	z = zapped(F)
	p = {'d': d, 'mod': mod, 'R': R, 'fasi': fasi(d + '/fasi.txt'), 'zapped': z}
	p['cicli'], p['errori_sha'] = ext4(d)
	p['comp_s'], p['comp_rc'] = compil(d)
	p['fermo'] = delta(F, '02-inizio', '02-fine', z)
	p['ext4'] = delta(F, '04-prova-inizio', '04-fine', z)
	p['comp'] = delta(F, '05-inizio', '05-fine', z)
	p['tutto'] = delta(F, '00-prima', '06-fine', z) or delta(F, '00-prima', max(F, key=lambda k: F[k]['t']) if F else '', z)
	p['lavoro'] = None
	try:
		t = open(d + '/kbuild-lavoro.txt', errors='replace').read()
		if 'LAVORO-FINE' in t:
			p['lavoro'] = dict(re.findall(r'^(\w+)=(\S*)\s*$', t, re.M))
	except FileNotFoundError:
		pass
	p['kbuild_id'] = None
	try:
		t = open(d + '/kbuild.log', errors='replace').read()
		bz = re.search(r'(\d+) \S+ \d+ \S+ arch/x86/boot/bzImage$', t, re.M)
		vm = re.search(r'(\d+) \S+ \d+ \S+ vmlinux$', t, re.M)
		eg = re.search(r'^(\d+)$', t, re.M)
		if bz and vm and eg:
			p['kbuild_id'] = {'bzImage': bz.group(1), 'vmlinux': vm.group(1), 'righe_errore': eg.group(1)}
	except FileNotFoundError:
		pass
	p['ext4_hdr'] = None
	try:
		m = re.search(r'^=== \S+ fase \S+, (.*)$', open(d + '/gapmem-A.log', errors='replace').read(), re.M)
		p['ext4_hdr'] = m.group(1).strip() if m else None
	except FileNotFoundError:
		pass
	p['lat'] = {}
	for f in ('04', '05'):
		try:
			p['lat'][f] = latenze(open('%s/lat-%s.txt' % (d, f), errors='replace').read())
		except FileNotFoundError:
			p['lat'][f] = None
	# controlli
	c = []
	t = p['tutto']
	if t is None:
		c.append('foto incomplete')
	else:
		if t['mismatch']: c.append('mismatch HPA %d' % t['mismatch'])
		if t['errori_shadow']: c.append('errori shadow %d' % t['errori_shadow'])
		if t['vpid02_off']: c.append('vCPU con VPID02 spento %d' % t['vpid02_off'])
	if p['errori_sha'] == p['errori_sha'] and p['errori_sha']: c.append('errori sha256 ext4 %d' % p['errori_sha'])
	if p['comp_rc'] != '0': c.append('compilazione rc=%s' % p['comp_rc'])
	conf = ''
	try:
		conf = open(d + '/configurazione.txt', errors='replace').read()
	except FileNotFoundError:
		c.append('configurazione assente')
	m = re.search(r'vept_scan_retries: (\d+)', conf)
	if R is not None and (not m or int(m.group(1)) != R):
		c.append('vept_scan_retries %s, atteso %s' % (m.group(1) if m else '?', R))
	for f in ('04', '05'):
		L = p['lat'][f]
		if L is not None and L.get('annidate'):
			c.append('latenza fase %s: %d rientri' % (f, L['annidate']))
		if L is not None and not L['coerente']:
			c.append('latenza fase %s: n=%s, istogrammi %s/%s' % (f, L.get('n'), L.get('reale_n'), L.get('servizio_n')))
	p['controlli'] = c
	return p

def g(p, *k):
	v = p
	for x in k:
		if v is None or not isinstance(v, dict):
			return NAN
		v = v.get(x, NAN)
	return v if isinstance(v, (int, float)) else NAN

def per(p, fase, k, unita):
	u = p['cicli'] if unita == 'ciclo' else 1
	return g(p, fase, k) / u if u and u == u else NAN

def analizza(base, mappa, retry):
	dirs = sorted(glob.glob(base + '/[0-9]*-*'), key=lambda x: int(os.path.basename(x).split('-')[0]))
	B = []
	for d in dirs:
		n, m = os.path.basename(d).split('-', 1)
		m = mappa.get(m, m)
		if m not in ('A', 'B'):
			continue
		B.append(braccio(d, m, retry.get(m)))
	return B

RIGHE = [
	('compilazione s', lambda p: p['comp_s'], -1),
	('ext4 cicli', lambda p: p['cicli'], +1),
	('fase 01 avvio s (con attesa ssh)', lambda p: p['fasi'].get('01-avvio', NAN), 0),
	('fase 03 avvio WSL2 s', lambda p: p['fasi'].get('03-avvio-wsl', NAN), 0),
	('fase 04 ext4 s', lambda p: p['fasi'].get('04-ext4', NAN), 0),
	('fase 05 compilazione s', lambda p: p['fasi'].get('05-compilazione', NAN), -1),
	('comp: EPT02 fault', lambda p: g(p, 'comp', 'ept02_fault'), -1),
	('comp: svuotamenti completi', lambda p: g(p, 'comp', 'full'), -1),
	('comp: di cui per race', lambda p: g(p, 'comp', 'full_race'), -1),
	('comp: INVEPT parziali', lambda p: g(p, 'comp', 'partial'), 0),
	('comp: foglie invalidate', lambda p: g(p, 'comp', 'foglie_invalidate'), -1),
	('comp: retry_1_success', lambda p: g(p, 'comp', 'retry_1_success'), 0),
	('comp: retry_2_success', lambda p: g(p, 'comp', 'retry_2_success'), 0),
	('comp: retry esauriti', lambda p: g(p, 'comp', 'retry_exhausted'), 0),
	('comp: retry per budget', lambda p: g(p, 'comp', 'retry_budget'), 0),
	('comp: uscite', lambda p: g(p, 'comp', 'uscite'), -1),
	('comp: CPU vCPU s', lambda p: g(p, 'comp', 'cpu_vcpu_s'), -1),
	('ext4: EPT02 fault / ciclo', lambda p: per(p, 'ext4', 'ept02_fault', 'ciclo'), -1),
	('ext4: svuotamenti completi / ciclo', lambda p: per(p, 'ext4', 'full', 'ciclo'), -1),
	('ext4: foglie invalidate / ciclo', lambda p: per(p, 'ext4', 'foglie_invalidate', 'ciclo'), -1),
	('ext4: retry_2_success', lambda p: g(p, 'ext4', 'retry_2_success'), 0),
	('comp: INVEPT n (DTrace)', lambda p: g(p, 'lat', '05', 'n'), 0),
	('comp: servizio media us', lambda p: g(p, 'lat', '05', 'servizio_media') / 1e3, -1),
	('comp: servizio p50 us', lambda p: g(p, 'lat', '05', 'servizio_p50') / 1e3, -1),
	('comp: servizio p95 us', lambda p: g(p, 'lat', '05', 'servizio_p95') / 1e3, -1),
	('comp: servizio p99 us', lambda p: g(p, 'lat', '05', 'servizio_p99') / 1e3, -1),
	('comp: servizio p99.9 us', lambda p: g(p, 'lat', '05', 'servizio_p99_9') / 1e3, -1),
	('comp: servizio max ms', lambda p: g(p, 'lat', '05', 'servizio_max') / 1e6, -1),
	('comp: reale p99.9 us', lambda p: g(p, 'lat', '05', 'reale_p99_9') / 1e3, -1),
	('comp: reale max ms', lambda p: g(p, 'lat', '05', 'reale_max') / 1e6, -1),
	('comp: reale > 2 ms', lambda p: g(p, 'lat', '05', 'reale_2ms'), -1),
	('comp: reale > 16 ms', lambda p: g(p, 'lat', '05', 'reale_16ms'), -1),
	('comp: servizio > 2 ms', lambda p: g(p, 'lat', '05', 'servizio_2ms'), -1),
	('comp: servizio > 16 ms', lambda p: g(p, 'lat', '05', 'servizio_16ms'), -1),
	('comp: op. con off_cpu (non attribuito)', lambda p: g(p, 'lat', '05', 'con_offcpu'), -1),
	('comp: off_cpu totale ms', lambda p: g(p, 'lat', '05', 'offcpu_somma') / 1e6, -1),
	('ext4: servizio p99.9 us', lambda p: g(p, 'lat', '04', 'servizio_p99_9') / 1e3, -1),
	('ext4: reale > 16 ms', lambda p: g(p, 'lat', '04', 'reale_16ms'), -1),
]

LAVORO_CHIAVI = ('AZIONI_CC', 'AZIONI_TOT', 'CONFIG', 'MAKEFILE', 'SORGENTI', 'SORGENTI_KB', 'GCC', 'MAKE', 'NPROC')

def workload(B):
	"""Parere #86 §2: SI se i quattro bracci hanno fatto lo stesso lavoro (stessa
	compilazione, stessa prova ext4), NO se differiscono, NON_VERIFICABILE se
	manca una misura. Criteri stretti: in 12 compilazioni reali del 24-25/10
	bzImage, vmlinux e righe d'errore erano identici."""
	manca, diff = [], []
	for i, p in enumerate(B):
		if p['lavoro'] is None: manca.append('braccio %d: kbuild-lavoro.txt' % (i + 1))
		if p['kbuild_id'] is None: manca.append('braccio %d: bzImage/vmlinux in kbuild.log' % (i + 1))
		if p['ext4_hdr'] is None: manca.append('braccio %d: intestazione ext4' % (i + 1))
	for k in LAVORO_CHIAVI:
		v = {(p['lavoro'] or {}).get(k) for p in B if p['lavoro'] is not None}
		if len(v) > 1: diff.append('%s %s' % (k, sorted(v)))
	for k in ('bzImage', 'vmlinux', 'righe_errore'):
		v = {p['kbuild_id'][k] for p in B if p['kbuild_id'] is not None}
		if len(v) > 1: diff.append('%s %s' % (k, sorted(v)))
	v = {p['ext4_hdr'] for p in B if p['ext4_hdr'] is not None}
	if len(v) > 1: diff.append('ext4 %s' % sorted(v))
	if len(B) != 4: manca.append('bracci %d/4' % len(B))
	if diff:
		return 'NO', diff + manca
	if manca:
		return 'NON_VERIFICABILE', manca
	return 'SI', []

def coppia(a, b, verso):
	"""verso -1: piu' basso e' meglio; +1: piu' alto; 0: solo descrittivo."""
	if a != a or b != b:
		return NAN
	return b - a

def stampa(B, out=sys.stdout):
	cont = defaultdict(int)
	ordine = []
	for p in B:
		cont[p['mod']] += 1
		ordine.append(p['mod'] + str(cont[p['mod']]))
	A = [p for p in B if p['mod'] == 'A']
	Bb = [p for p in B if p['mod'] == 'B']
	pr = lambda *a: print(*a, file=out)
	pr('######## bracci: ' + ' '.join('%s(%s, retry=%s)' % (o, os.path.basename(p['d']), p['R']) for o, p in zip(ordine, B)))
	for o, p in zip(ordine, B):
		pr('controlli %-4s %s' % (o, 'OK' if not p['controlli'] else 'NO: ' + '; '.join(p['controlli'])))
	struttura = [p['mod'] for p in B] == ['A', 'B', 'B', 'A']
	pr('struttura ABBA: %s' % ('OK' if struttura else 'NO (%s)' % ''.join(p['mod'] for p in B)))
	pr()
	pr('%-38s' % '' + ''.join('%12s' % o for o in ordine) + '%12s%12s%9s%10s%10s  %s' % ('Amean', 'Bmean', 'delta%', 'B1-A1', 'B2-A2', 'coppie'))
	esiti = {}
	for nome, f, verso in RIGHE:
		v = [f(p) for p in B]
		am = st.mean([f(p) for p in A]) if A else NAN
		bm = st.mean([f(p) for p in Bb]) if Bb else NAN
		dp = 100 * (bm / am - 1) if am == am and am else NAN
		d1 = coppia(f(B[0]), f(B[1]), verso) if struttura else NAN
		d2 = coppia(f(B[3]), f(B[2]), verso) if struttura else NAN
		if d1 != d1 or d2 != d2:
			co = 'n.d.'
		elif d1 == 0 and d2 == 0:
			co = 'UGUALI'
		elif (d1 > 0) == (d2 > 0) and d1 != 0 and d2 != 0:
			co = 'COERENTE'
		else:
			co = 'CONTRADDITTORIO'
		esiti[nome] = (co, d1, d2, verso)
		fm = lambda x: '%12s' % 'n.d.' if x != x else '%12.1f' % x
		pr('%-38s' % nome + ''.join(fm(x) for x in v) + fm(am) + fm(bm) +
		    ('%9s' % 'n.d.' if dp != dp else '%9.1f' % dp) + ('%10s' % 'n.d.' if d1 != d1 else '%10.1f' % d1) +
		    ('%10s' % 'n.d.' if d2 != d2 else '%10.1f' % d2) + '  ' + co)
	pr()
	ok = struttura and all(not p['controlli'] for p in B)
	co, d1, d2, _ = esiti['compilazione s']
	# regola del parere #85 §3.3, confermata dal #86 §1 come classificazione
	# DIREZIONALE pre-registrata: le due coppie nello stesso senso -> MIGLIORA o
	# PEGGIORA, altrimenti INCONCLUSIVE. Non e' significativita' statistica.
	c = [p['comp_s'] for p in B]
	wl, wn = workload(B)
	pr('WORKLOAD_COMPARABILE=%s%s' % (wl, (' (' + '; '.join(wn) + ')') if wn else ''))
	if struttura:
		Dd = st.mean([c[1], c[2]]) - st.mean([c[0], c[3]])
		pc1, pc2 = 100 * d1 / c[0], 100 * d2 / c[3]		# ciascuna sul PROPRIO A locale
		disp = max(abs(c[0] - c[3]), abs(c[1] - c[2]))
		pr('compilazione: d1=B1-A1 %+.1f s (%+.2f%% di A1), d2=B2-A2 %+.1f s (%+.2f%% di A2), D=Bmean-Amean %+.1f s, delta_pct %+.2f%%, dispersione fra repliche %.1f s' % (
		    d1, pc1, d2, pc2, Dd, 100 * (st.mean([c[1], c[2]]) / st.mean([c[0], c[3]]) - 1), disp))
	if not ok:
		v = 'INCONCLUSIVE (struttura o controlli di correttezza non superati)'
	elif wl != 'SI':
		v = 'INCOMPLETA (lavoro non dimostrato uguale nei quattro bracci: WORKLOAD_COMPARABILE=%s)' % wl
	elif co == 'COERENTE':
		v = 'MIGLIORA' if d1 < 0 else 'PEGGIORA'
		v += ' (compilazione: d1 %+.1f s, d2 %+.1f s)' % (d1, d2)
	else:
		v = 'INCONCLUSIVE (compilazione %s: d1 %+.1f s, d2 %+.1f s)' % (co, d1, d2)
	# EVIDENZA (#86 §1), soglie FISSATE PRIMA DEI DATI il 27/10/2026, solo se le
	# coppie concordano: effetto conservativo = minore dei due |d|/A locale
	#   DEBOLE        conservativo < 1%%
	#   SUGGESTIVA    conservativo >= 3%% E |D| > dispersione fra repliche
	#   DA_REPLICARE  altrimenti
	if v.startswith(('MIGLIORA', 'PEGGIORA')):
		cons = min(abs(pc1), abs(pc2))
		ev = 'DEBOLE' if cons < 1 else ('SUGGESTIVA' if cons >= 3 and abs(Dd) > disp else 'DA_REPLICARE')
		pr('EVIDENZA=%s (effetto conservativo %.2f%%, |D| %.1f s, dispersione %.1f s)' % (ev, cons, abs(Dd), disp))
	else:
		pr('EVIDENZA=NESSUNA')
	pr('VERDETTO_PRESTAZIONI=%s' % v)
	pr('LATENZE (bucket llquantize [lo, hi) in us; n = operazioni; off_cpu = reale - su CPU, NON attribuito a una causa):')
	for o, p in zip(ordine, B):
		for f, nome in (('04', 'ext4'), ('05', 'comp')):
			L = p['lat'].get(f)
			if L is None:
				pr('  %-3s %-4s non disponibile' % (o, nome)); continue
			q = lambda k: '[%s, %s)' % ('%.1f' % (L[k] / 1e3) if L[k] == L[k] else 'n.d.', '%.1f' % (L[k + '_hi'] / 1e3) if L[k + '_hi'] == L[k + '_hi'] else 'oltre')
			pr('  %-3s %-4s n=%d servizio p50 %s p99 %s p99.9 %s max %.2f ms | reale p99.9 %s max %.2f ms >2ms %d >16ms %d | off_cpu %d op, %.1f ms%s%s' % (
			    o, nome, L.get('n', 0), q('servizio_p50'), q('servizio_p99'), q('servizio_p99_9'), L.get('servizio_max', 0) / 1e6,
			    q('reale_p99_9'), L.get('reale_max', 0) / 1e6, L.get('reale_2ms', 0), L.get('reale_16ms', 0),
			    L.get('con_offcpu', 0), L.get('offcpu_somma', 0) / 1e6,
			    ' | p99.9 INSTABILE (<10 campioni in coda)' if L['coda_instabile'] else '',
			    '' if L['coerente'] else ' | NUMEROSITA INCOERENTE'))
	r2 = sum(g(p, 'tutto', 'retry_2_success') for p in Bb if g(p, 'tutto', 'retry_2_success') == g(p, 'tutto', 'retry_2_success'))
	pr('RETRY2_SUCCESS=%s (somma nei bracci B: %s)' % ('COVERED' if r2 > 0 else 'NOT_COVERED', r2))
	pr('DEFAULT: invariato (vept_scan_retries=1) fino a una decisione separata')
	pr('NON DISPONIBILE: temperatura delle CPU (coretemp non caricato); latenza dove lat-*.txt manca')
	return v

if __name__ == '__main__':
	a = sys.argv[1:]
	if a and a[0] == '--lat':
		r = latenze(open(a[1]).read())
		print(r if r is not None else 'LATENZA NON CHIUSA')
		sys.exit(0)
	opz = {'--mappa': '', '--retry': 'A=1,B=2'}
	pos = []
	while a:
		x = a.pop(0)
		if x in opz:
			opz[x] = a.pop(0)
		else:
			pos.append(x)
	mappa = dict(kv.split('=') for kv in opz['--mappa'].split(',') if kv)
	retry = {k: int(v) for k, v in (kv.split('=') for kv in opz['--retry'].split(',') if kv)}
	stampa(analizza(pos[0], mappa, retry))
