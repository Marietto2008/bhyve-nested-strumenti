#!/usr/local/bin/python3
# abba_parere87.py -- Claude 27/10/2026, parere #87 §5.2-5.3: grandezze derivate
# dall'ABBA a 2 VP, lette DIRETTAMENTE dai file della campagna (sola lettura):
#  - tasso condizionato di successo del TERZO tentativo, con denominatore
#    verificato: R2 = operazioni arrivate al terzo tentativo. Con retries=2 e
#    senza uscite non-race/budget: retries_done = ok1 + 2*R2 e R2 = ok2 + esauriti.
#    Con retries=1: retries_done = ok1 + esauriti (+ nonrace + budget).
#  - operazioni INVEPT > 2 ms per 1000 INVEPT; servizio INVEPT totale (somma
#    esatta da DTrace, non da medie arrotondate).
# Uso: abba_parere87.py <cartella della campagna>
import glob, os, re, sys

def foto(path):
	F, cur = {}, None
	for l in open(path, errors='replace'):
		m = re.match(r'FOTO (\S+) ', l)
		if m:
			cur = m.group(1); F[cur] = {}; continue
		m = re.match(r'hw\.vmm\.vmx\.(\S+): (\d+)$', l.strip())
		if m and cur:
			F[cur][m.group(1)] = int(m.group(2))
	return F

def conta(path):
	try:
		return {k: int(v) for k, v in re.findall(r'^CONTA (\w+)=\s*(\d+)', open(path).read(), re.M)}
	except FileNotFoundError:
		return {}

K = ['vept_scan_retries_done', 'vept_scan_retry_1_success', 'vept_scan_retry_2_success',
     'vept_scan_retry_exhausted', 'vept_scan_retry_nonrace_fallback', 'vept_scan_retry_budget_fallback',
     'vept_keep_scan_race_fallbacks', 'vept_scan_first_pass_ok']
FASI = {'comp': ('05-inizio', '05-fine'), 'ext4': ('04-prova-inizio', '04-fine'), 'tutto': ('00-prima', '06-fine')}

base = sys.argv[1]
tot = {}
for d in sorted(glob.glob(base + '/[0-9]-[AB]')):
	b = os.path.basename(d)
	R = 2 if b.endswith('B') else 1
	F = foto(d + '/foto.txt')
	print('== %s (retries=%d)' % (b, R))
	for f, (a, z) in FASI.items():
		if a not in F or z not in F:
			print('  %-5s foto mancanti' % f); continue
		x = {k: F[z].get(k, 0) - F[a].get(k, 0) for k in K}
		rd, ok1, ok2, ex, nr, bu = (x[k] for k in K[:6])
		if R == 2:
			# budget: un taglio DOPO il 2o tentativo (b1) conta fra gli esauriti senza
			# terzo tentativo; uno dopo il 1o non avvia nulla. Con nonrace = 0:
			#   rd = ok1 + 2*R2 + b1,  esauriti = esauriti3 + b1,  R2 = ok2 + esauriti3
			#   => b1 = 2*(ok2 + esauriti) + ok1 - rd, con 0 <= b1 <= budget
			b1 = 2 * (ok2 + ex) + ok1 - rd
			r2 = ok2 + ex - b1				# arrivate al terzo tentativo
			chiusa = (nr == 0 and 0 <= b1 <= bu)
			tasso = 100 * ok2 / r2 if r2 else float('nan')
			print('  %-5s retries_done %d ok1 %d ok2 %d esauriti %d nonrace %d budget %d -> tagli dopo il 2o tentativo %d, arrivate al 3o %d, identita %s; successo al 3o tentativo %d/%d = %.1f%%' % (
			    f, rd, ok1, ok2, ex, nr, bu, b1, r2, 'VERIFICATA' if chiusa else 'NON verificata', ok2, r2, tasso))
			if f in ('comp', 'ext4', 'tutto'):
				t = tot.setdefault(f, [0, 0, True]); t[0] += ok2; t[1] += r2; t[2] &= chiusa
		else:
			# retries=1: un taglio per budget puo' solo impedire il 2o tentativo (nessun conteggio)
			chiusa = (rd == ok1 + ex + nr)
			tasso = 100 * ok1 / (ok1 + ex) if ok1 + ex else float('nan')
			print('  %-5s retries_done %d ok1 %d esauriti %d nonrace %d budget %d -> identita rd=ok1+esauriti+nonrace %s; successo al 2o tentativo %.1f%%' % (
			    f, rd, ok1, ex, nr, bu, 'VERIFICATA' if chiusa else 'NON verificata', tasso))
	for f in ('04', '05'):
		c = conta('%s/lat-%s.txt' % (d, f))
		if not c:
			print('  lat-%s assente' % f); continue
		n = c['n']
		print('  lat-%s n=%d  >2ms %d = %.2f per 1000 INVEPT  >16ms %d  servizio totale %.3f s CPU  reale totale %.3f s' % (
		    f, n, c.get('servizio_2ms', 0), 1000 * c.get('servizio_2ms', 0) / n, c.get('servizio_16ms', 0),
		    c.get('servizio_somma', 0) / 1e9, c.get('reale_somma', 0) / 1e9))
for f, (s, n, ok) in tot.items():
	print('TERZO TENTATIVO %-5s bracci B: %d/%d = %.1f%% (identita del denominatore %s)' % (f, s, n, 100 * s / n if n else float('nan'), 'VERIFICATA in entrambi' if ok else 'NON verificata'))
