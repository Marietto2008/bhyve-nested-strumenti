#!/usr/local/bin/python3
# misura8vp_an.py -- Claude 27/10/2026, parere #88 §2-4: confronto ESPLORATIVO fra bracci a 8 VP
# (A = vept_scan_retries 1, B = 2; budget invariato 2000 us). Una sessione per braccio, non
# replicato: nessun verdetto prestazionale, solo grandezze affiancate. Per fase (ext4 = finestra
# 04-prova-inizio..04-fine, compilazione = 05-inizio..05-fine):
#  - tempi: finestra delle foto, `time real` della compilazione, cicli ext4;
#  - INVEPT di L1: numero, per unita' di lavoro, per secondo; gestore (abba-invept-lat.d): CPU
#    totale, quota sul tempo vCPU della finestra, media per operazione, p50/p95/p99/p99.9 come
#    bucket [lo, hi), massimo, operazioni oltre 2/4/8/16 ms (confini ESATTI dei bucket llquantize
#    a 100 passi per decade), off_cpu (non attribuito);
#  - scansione B1: primo passaggio ok, ritentativi avviati, successi al 2o/3o tentativo, esauriti,
#    tagli per budget, non-race, svuotamenti (totali e per race), foglie invalidate, per INVEPT L1;
#  - fault EPT02: totale, per unita' di lavoro, per secondo per VP; INVEPT del prologo: quota;
#  - correttezza: mismatch HPA, errori shadow.
# Uso: misura8vp_an.py <cartella braccio A> <cartella braccio B> [--vp 8]
import importlib.util, os, re, sys

T = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('an', os.path.join(T, 'abba_retry_an.py'))
an = importlib.util.module_from_spec(spec); spec.loader.exec_module(an)
TSC = 3600018355
NAN = float('nan')

def istogramma(testo, nome):
	m = re.search(r'== ISTOGRAMMA %s ==\n(.*?)(?=== ISTOGRAMMA|== LATENZA CHIUSA)' % nome, testo, re.S)
	return sorted((int(v), int(c)) for v, c in re.findall(r'^\s*(\d+) \|[@ ]*\s(\d+)\s*$', m.group(1) if m else '', re.M))

def oltre(isto, soglia_ns):
	"""operazioni con valore >= soglia: esatto se la soglia e' un confine di bucket"""
	return sum(c for v, c in isto if v >= soglia_ns)

def braccio(d, vp):
	F = an.leggi_foto(d + '/foto.txt')
	r = {}
	for fase, (a, z), lat in (('ext4', ('04-prova-inizio', '04-fine'), '04'), ('comp', ('05-inizio', '05-fine'), '05')):
		if a not in F or z not in F:
			continue
		A, Z = F[a], F[z]
		x = lambda k: Z['s']['x:' + k] - A['s']['x:' + k]
		f = {'finestra_s': Z['t'] - A['t'], 'cpu_vcpu_s': Z['cpu'] - A['cpu']}
		for k in ('vept_invept_single', 'vept_scan_first_pass_ok', 'vept_scan_retries_done', 'vept_scan_retry_1_success',
		          'vept_scan_retry_2_success', 'vept_scan_retry_exhausted', 'vept_scan_retry_budget_fallback',
		          'vept_scan_retry_nonrace_fallback', 'vept_keep_full_fallbacks', 'vept_keep_scan_race_fallbacks',
		          'vept_keep_partial_invepts', 'vept_keep_invalidated_leaves', 'vept_leaves_zapped_race',
		          'nested_ept02_faults_l0', 'nested_invept_entry_total', 'nested_invept_tsc', 'vept_keep_verify_mismatch',
		          'nested_sh_faults', 'vept_leaves_zapped_capacity', 'vept_leaves_zapped_alias',
		          'vept_leaves_zapped_backing', 'vept_leaves_zapped_force', 'vept_leaves_zapped_other'):
			f[k] = x(k)
		f['budget_us'] = A['s']['x:vept_scan_budget_us']; f['retries_cfg'] = A['s']['x:vept_scan_retries']
		f['budget_us_fine'] = Z['s']['x:vept_scan_budget_us']
		try:
			t = open('%s/lat-%s.txt' % (d, lat), errors='replace').read()
			L = an.latenze(t)
			si = istogramma(t, 'servizio')
			f['lat'] = L
			ri = istogramma(t, 'reale')
			for ms in (2, 4, 8, 16):
				f['oltre_%dms' % ms] = oltre(si, ms * 1000000)
				f['reale_oltre_%dms' % ms] = oltre(ri, ms * 1000000)
		except FileNotFoundError:
			f['lat'] = None
		r[fase] = f
	r['comp_real'], r['comp_rc'] = an.compil(d)
	r['cicli'], r['errori_sha'] = an.ext4(d)
	r['vp'] = vp
	return r

def decomponi(f):
	"""Tagli per budget prima del 2o (b0) e del 3o (b1) tentativo, esauriti al 3o (ex3), arrivati
	al 3o (r2). Semantica verificata su vmx_vept.c:1410-1430 (un taglio dopo un ritentativo conta
	anche fra gli esauriti; nonrace = uscita non-race dopo un ritentativo). Con retries=2:
	  rd = ok1 + 2*R2 + b1 + nr1,  esauriti = ex3 + b1,  R2 = ok2 + ex3 + nr2,  nr = nr1 + nr2
	Si provano tutte le collocazioni del nonrace; si tiene quella in cui b0 + b1 + ex3 coincide col
	contatore degli svuotamenti per race (chiusura). Con retries=1: rd = ok1 + esauriti + nonrace."""
	rd, ok1, ok2 = f['vept_scan_retries_done'], f['vept_scan_retry_1_success'], f['vept_scan_retry_2_success']
	ex, bu, nr, racefb = (f['vept_scan_retry_exhausted'], f['vept_scan_retry_budget_fallback'],
	    f['vept_scan_retry_nonrace_fallback'], f['vept_keep_scan_race_fallbacks'])
	if f['retries_cfg'] == 1:
		return {'b0': bu, 'b1': 0, 'ex3': 0, 'r2': 0, 'chiusa': rd == ok1 + ex + nr, 'race_attesi': bu + ex}
	sol = []
	for nr1 in range(nr + 1):
		nr2 = nr - nr1
		b1 = ok1 + 2 * ok2 + 2 * ex + 2 * nr2 + nr1 - rd
		ex3 = ex - b1; r2 = ok2 + ex3 + nr2; b0 = bu - b1
		if min(b1, ex3, b0) < 0:
			continue
		sol.append({'b0': b0, 'b1': b1, 'ex3': ex3, 'r2': r2, 'race_attesi': b0 + b1 + ex3,
		            'chiusa': b0 + b1 + ex3 == racefb})
	chiuse = [z for z in sol if z['chiusa']]
	return (chiuse or sol or [{'b0': NAN, 'b1': NAN, 'ex3': NAN, 'r2': NAN, 'race_attesi': NAN, 'chiusa': False}])[0]

def righe(fase, f, r):
	u = r['cicli'] if fase == 'ext4' else 1
	nome_u = 'ciclo ext4' if fase == 'ext4' else 'compilazione'
	L = f['lat'] or {}
	# parere #90 §4: i tassi «per 1000» usano le operazioni CAMPIONATE da DTrace (stesso insieme
	# delle soglie); il contatore del modulo si mostra accanto, non si mescolano i denominatori
	n1 = L.get('n') or NAN
	cpu_g = L.get('servizio_somma', NAN) / 1e9
	b = lambda k: '[%.0f, %.0f) us' % (L.get(k, NAN) / 1e3, L.get(k + '_hi', NAN) / 1e3) if L else 'n.d.'
	z = decomponi(f)
	return [
		('configurazione letta dalle foto: retry / budget', '%d / %d us (fine fase %d)' % (f['retries_cfg'], f['budget_us'], f['budget_us_fine'])),
		('finestra delle foto (s)', f['finestra_s']),
		('CPU vCPU nella finestra (s)', f['cpu_vcpu_s']),
		('INVEPT di L1 (contatore del modulo, solo tipo 1)', f['vept_invept_single']),
		('INVEPT di L1 campionati da DTrace (denominatore dei tassi)', L.get('n', NAN)),
		('INVEPT di L1 per %s' % nome_u, f['vept_invept_single'] / u),
		('INVEPT di L1 al secondo', f['vept_invept_single'] / f['finestra_s']),
		('gestore: CPU totale (s)', cpu_g),
		('gestore: quota del tempo vCPU (%)', 100 * cpu_g / f['cpu_vcpu_s']),
		('gestore: media per operazione (us)', L.get('servizio_media', NAN) / 1e3),
		('gestore: p50', b('servizio_p50')), ('gestore: p95', b('servizio_p95')),
		('gestore: p99', b('servizio_p99')), ('gestore: p99.9', b('servizio_p99_9')),
		('gestore: massimo (ms)', L.get('servizio_max', NAN) / 1e6),
		('gestore: oltre 2 ms', f.get('oltre_2ms', NAN)), ('gestore: oltre 4 ms', f.get('oltre_4ms', NAN)),
		('gestore: oltre 8 ms', f.get('oltre_8ms', NAN)), ('gestore: oltre 16 ms', f.get('oltre_16ms', NAN)),
		('gestore: oltre 2 ms per 1000 INVEPT', 1000 * f.get('oltre_2ms', NAN) / n1),
		('gestore: oltre 4 ms per 1000 INVEPT', 1000 * f.get('oltre_4ms', NAN) / n1),
		('gestore: oltre 8 ms per 1000 INVEPT', 1000 * f.get('oltre_8ms', NAN) / n1),
		('gestore: oltre 16 ms per 1000 INVEPT', 1000 * f.get('oltre_16ms', NAN) / n1),
		('gestore REALE: p99 / p99.9', '%s / %s' % (b('reale_p99'), b('reale_p99_9'))),
		('gestore REALE: massimo (ms)', L.get('reale_max', NAN) / 1e6),
		('gestore REALE: oltre 2/4/8/16 ms', '%s/%s/%s/%s' % tuple(f.get('reale_oltre_%dms' % m, 'n.d.') for m in (2, 4, 8, 16))),
		('gestore: op. con off_cpu / totale off_cpu (ms)', '%s / %.1f' % (L.get('con_offcpu', 'n.d.'), L.get('offcpu_somma', NAN) / 1e6)),
		('scansione: primo passaggio ok', f['vept_scan_first_pass_ok']),
		('scansione: ritentativi avviati', f['vept_scan_retries_done']),
		('scansione: successi al 2o tentativo', f['vept_scan_retry_1_success']),
		('scansione: successi al 3o tentativo', f['vept_scan_retry_2_success']),
		('svuotamenti: esauriti dopo i ritentativi', f['vept_scan_retry_exhausted']),
		('svuotamenti: tagliati dal budget', f['vept_scan_retry_budget_fallback']),
		('svuotamenti: non-race', f['vept_scan_retry_nonrace_fallback']),
		('decomposizione: tagli prima del 2o tentativo', z['b0']),
		('decomposizione: tagli prima del 3o tentativo', z['b1']),
		('decomposizione: esauriti AL 3o tentativo', z['ex3']),
		('decomposizione: arrivati al 3o tentativo', z['r2']),
		('decomposizione: successo al 3o tentativo (%)', 100 * f['vept_scan_retry_2_success'] / z['r2'] if z['r2'] else NAN),
		('decomposizione: chiusa sul contatore race', 'SI' if z['chiusa'] else 'NO (attesi %s)' % z['race_attesi']),
		('svuotamenti non-race (totale - race)', f['vept_keep_full_fallbacks'] - f['vept_keep_scan_race_fallbacks']),
		('foglie eliminate non-race: capacita/alias/backing/force/altro', '%d/%d/%d/%d/%d' % tuple(f[k] for k in (
		    'vept_leaves_zapped_capacity', 'vept_leaves_zapped_alias', 'vept_leaves_zapped_backing',
		    'vept_leaves_zapped_force', 'vept_leaves_zapped_other'))),
		('svuotamenti completi (totale)', f['vept_keep_full_fallbacks']),
		('svuotamenti per race', f['vept_keep_scan_race_fallbacks']),
		('svuotamenti per 1000 INVEPT di L1 (contatore)', 1000 * f['vept_keep_full_fallbacks'] / (f['vept_invept_single'] or NAN)),
		('foglie invalidate', f['vept_keep_invalidated_leaves']),
		('foglie eliminate per race', f['vept_leaves_zapped_race']),
		('fault EPT02', f['nested_ept02_faults_l0']),
		('fault EPT02 per %s' % nome_u, f['nested_ept02_faults_l0'] / u),
		('fault EPT02 al secondo per VP', f['nested_ept02_faults_l0'] / f['finestra_s'] / r['vp']),
		('INVEPT del prologo: quota del tempo vCPU (%)', 100 * f['nested_invept_tsc'] / TSC / f['cpu_vcpu_s']),
		('mismatch HPA / errori shadow', '%d / %d' % (f['vept_keep_verify_mismatch'], f['nested_sh_faults'])),
	]

def fmt(v):
	if isinstance(v, str): return v
	if v != v: return 'n.d.'
	return '%.2f' % v if abs(v) < 100 and v != int(v) else '%d' % round(v)

if __name__ == '__main__':
	a = sys.argv[1:]
	vp = 8
	if '--vp' in a:
		i = a.index('--vp'); vp = int(a[i + 1]); del a[i:i + 2]
	R = [braccio(d, vp) for d in a]
	print('CONFRONTO ESPLORATIVO a %d VP (una sessione per braccio, NON replicato: nessun verdetto)' % vp)
	print('bracci: ' + ' | '.join(a))
	print('%-50s' % 'compilazione: time real (s), rc' + ''.join('%22s' % ('%.1f, rc=%s' % (r['comp_real'], r['comp_rc'])) for r in R))
	print('%-50s' % 'ext4: cicli, errori sha256' + ''.join('%22s' % ('%s, %s' % (r['cicli'], r['errori_sha'])) for r in R))
	for fase in ('comp', 'ext4'):
		print('\n######## %s' % ('COMPILAZIONE' if fase == 'comp' else 'EXT4'))
		tab = [righe(fase, r[fase], r) for r in R if fase in r]
		for i in range(len(tab[0])):
			vals = [t[i][1] for t in tab]
			extra = ''
			if len(vals) == 2 and all(isinstance(v, (int, float)) and v == v for v in vals) and vals[0]:
				extra = '%10s' % ('%+.1f%%' % (100 * (vals[1] / vals[0] - 1)))
			print('%-50s' % tab[0][i][0] + ''.join('%22s' % fmt(v) for v in vals) + extra)
