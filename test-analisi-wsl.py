#!/usr/local/bin/python3
# test-analisi-wsl.py -- Claude 01/11/2026, revisione 2 dopo il parere #171 di Astra (par. 3), 3 dopo il #172. Collaudo di
# analisi-wsl-corsa.py rev. 2, come utente collaudo. Gli esemplari usano la forma REALE dell'uscita di sonde-wsl-v2.d e
# le righe REALI di stats.txt della corsa c1/2 (logs/campagna-wsl-1/corsa2), con valori scelti per caso. Comprende le
# due controprove di Astra: (1) intervalli non allineati (contatori T=100..117, finestra DTrace 110..120) devono restare
# SEPARATI, ciascuno con la sua durata; (2) un campione con una sola vCPU NON deve dare -80 ma NA, segnalato.
# Uso: sudo -u collaudo python3 test-analisi-wsl.py <cartella nuova in collaudi>
import os, pwd, subprocess, sys
os.environ['PATH'] = '/bin:/usr/bin:/sbin:/usr/sbin:/mnt/linuxulator2/vm/nested-work/collaudo-bin'
if pwd.getpwuid(os.getuid()).pw_name != 'collaudo':
	print('STOP: le suite girano solo come utente collaudo'); raise SystemExit(2)
W = '/mnt/linuxulator2/vm/nested-work'
O = sys.argv[1]
if not O.startswith(W + '/collaudi/') or os.path.exists(O):
	print('cartella non valida o esistente'); raise SystemExit(2)
os.makedirs(O)
RIGHE = [l for l in open(W + '/logs/campagna-wsl-1/corsa2/stats.txt').read().split('\n') if l.strip()]
SERIE = ['ingressi in L2', "exit riflesse all'L1", 'exit nested gestite nello slow path',
         'vm exits for instruction emulation', 'immediate exit armate da L0', 'vm exits due to interrupt window opening',
         'vcpu migration across host cpus']


def campione(t, val, vcpu=('vcpu0', 'vcpu1'), extra=''):
	"""un campione con le righe REALI della corsa c1/2, i contatori della serie posti a val[(vcpu, nome)] o 0"""
	out = ['T %d' % t]
	for l in RIGHE:
		v = l.split(' ', 1)[0]
		if v not in vcpu:
			continue
		k = l.split(' ', 1)[1].rsplit('\t', 1)[0].strip() if '\t' in l else None
		if k in SERIE:
			out.append('%s\t%d' % (l.rsplit('\t', 1)[0], val.get((v, k), 0)))
		else:
			out.append(l)
	return '\n'.join(out) + ('\n' + extra if extra else '') + '\n'


def corsa(n, sonde, serie, fasi='avvio 90\ndesktop 105\nwsl_inizio 112\n', err='', attese='vcpu 2\n'):
	d = os.path.join(O, n)
	os.makedirs(d)
	if attese is not None:
		open(d + '/serie-attese.txt', 'w').write(attese)
	open(d + '/sonde.txt', 'w').write(sonde)
	open(d + '/sonde-err.txt', 'w').write(err)
	if serie is not None:
		open(d + '/stats-serie.txt', 'w').write(serie)
	open(d + '/fasi.txt', 'w').write(fasi)
	p = subprocess.run(['python3', W + '/analisi-wsl-corsa.py', d], capture_output=True, text=True)
	open(d + '/uscita.txt', 'w').write(p.stdout + p.stderr)
	return p


nok = nko = 0


def vero(c, msg):
	global nok, nko
	nok += bool(c); nko += not c
	print('  %s %s' % ('ok    ' if c else 'ERRATO', msg))


def righe(p, pref):
	return [l for l in p.stdout.split('\n') if l.split()[:len(pref)] == pref]


L2 = 'ingressi in L2'
SON = 'DTRACE_ATTIVO sonde-wsl-v2\nF 100\nL2 48 900\nL2 30 100\nRIF 48 50\nF 110\nL2 48 9000\nL2 1 1000\nRIF 48 4000\nF 120\nL2 48 7\nDTRACE_FINE\n'

# 1. controprova di Astra: contatori a T=100 e T=117 (17 s), finestre DTrace 100..110 e 110..120 (10 s)
v1 = {(c, k): 100 for c in ('vcpu0', 'vcpu1') for k in SERIE}
v2 = {(c, k): 100 + (170 if c == 'vcpu0' else 34) for c in ('vcpu0', 'vcpu1') for k in SERIE}
p = corsa('allineamento', SON, campione(100, v1) + campione(117, v2))
print(p.stdout)
vero(p.returncode == 0, 'allineamento: uscita 0')
# le righe L2 dopo "F 110" sono l'aggregato accumulato FINO al tick 110: la finestra 100..110 (da +10 a +20)
w = righe(p, ['10', '20', '10'])
vero(len(w) == 1 and '10000' in w[0].split() and 'EPTVIOL 90%, EXTINT 10%' in w[0], 'finestra DTrace 100..110 con la SUA durata (10 s): %r' % w)
w = righe(p, ['20', '30', '10'])
vero(len(w) == 1 and w[0].split()[4] == '7', 'finestra DTrace 110..120 (10 s, ultima): 7 uscite: %r' % w)
iv = righe(p, ['10', '27', '17'])
vero(len(iv) == 3, 'intervallo dei contatori 100..117 con la SUA durata (17 s), per vCPU e totale: %d righe' % len(iv))
tot = [l for l in iv if l.split()[4] == 'tot']
vero(len(tot) == 1 and tot[0].split()[5] == '12', 'tasso totale ingressi in L2 = (170+34)/17 = 12/s: %r' % tot)
v0 = [l for l in iv if l.split()[4] == 'vcpu0']
vero(len(v0) == 1 and v0[0].split()[5] == '10', 'tasso vcpu0 = 170/17 = 10/s: %r' % v0)
vero(not any(' 10 ' in l and '40' in l.split() for l in iv), 'nessun "+40" attribuito alla finestra DTrace')

# 2. controprova di Astra: a T=117 solo vcpu0=120 (gli altri assenti) -> NA e segnalazione, mai -80
v3 = {('vcpu0', k): 120 for k in SERIE}
p = corsa('vcpu_mancante', SON, campione(100, {(c, k): 100 for c in ('vcpu0', 'vcpu1') for k in SERIE}) +
          campione(117, v3, vcpu=('vcpu0',)))
iv = righe(p, ['10', '27', '17'])
vero(p.returncode == 0 and '-80' not in p.stdout, 'vcpu mancante: nessun -80 nell\'uscita')
vero(all('NA' in l for l in iv) and len(iv) == 3, 'vcpu mancante: intervallo NA per ogni riga: %r' % iv)
vero('vCPU mancante vcpu1' in p.stdout and 'campione incompleto' in p.stdout, 'vcpu mancante: segnalato')

# 3. delta negativo (contatore che scende con tutte le vCPU presenti) -> NA e segnalazione
v4 = dict(v1); v4[('vcpu1', L2)] = 50
p = corsa('negativo', SON, campione(100, v1) + campione(110, v4))
iv = [l for l in righe(p, ['10', '20', '10']) if l.split()[4] in ('vcpu1', 'tot')]
vero(len(iv) == 2 and all(l.split()[5] == 'NA' for l in iv) and 'delta NEGATIVO' in p.stdout, 'delta negativo: NA e segnalato: %r' % iv)

# 4. riga doppia e riga d'errore nella serie
p = corsa('doppia', SON, campione(100, v1, extra='vcpu0 ingressi in L2                        \t999') +
          campione(110, v2, extra='vcpu1 bhyvectl: vm_get_stats: No such file or directory'))
vero('riga doppia per vcpu0 ingressi in L2' in p.stdout, 'riga doppia segnalata')
# rev. 3 (parere #172): il caso di Astra -- il doppione sovrascriveva e il totale diventava 13/s: ora il campione e' INVALIDO
iv = [l for l in righe(p, ['10', '20', '10']) if l.split()[4] in ('vcpu0', 'vcpu1', 'tot')]
vero(len(iv) == 3 and all(l.split()[5] == 'NA' for l in iv) and ' 13 ' not in ' '.join(iv), 'doppione: intervallo NA, nessun 13/s: %r' % iv)
vero('campione T 110: 1 righe non riconosciute' in p.stdout, 'riga d\'errore di bhyvectl segnalata')

# 4b. (#172) vcpu1 assente in TUTTA la raccolta: con le vCPU attese dalla configurazione (2) i campioni sono incompleti
s0 = {('vcpu0', k): 100 for k in SERIE}
s1 = {('vcpu0', k): 200 for k in SERIE}
p = corsa('vcpu1_mai', SON, campione(100, s0, vcpu=('vcpu0',)) + campione(110, s1, vcpu=('vcpu0',)))
iv = [l for l in righe(p, ['10', '20', '10']) if l.split()[4] in ('vcpu0', 'vcpu1', 'tot')]
vero('vCPU mancante vcpu1' in p.stdout and len(iv) == 3 and all('NA' in l for l in iv), 'vcpu1 mai vista, 2 attese: NA e segnalata: %r' % iv)
p = corsa('attese_non_dichiarate', SON, campione(100, s0, vcpu=('vcpu0',)) + campione(110, s1, vcpu=('vcpu0',)), attese=None)
vero('vCPU attese NON dichiarate' in p.stdout, 'senza serie-attese.txt: segnalazione esplicita')
# 4c. (#172) TF: lettura lenta del campione segnalata
p = corsa('lettura_lenta', SON, campione(100, v1, extra='TF 104') + campione(110, v2, extra='TF 110'))
vero('campione T 100: lettura durata 4 s' in p.stdout, 'lettura di 4 s segnalata')

# 5. finestre parziali e cambio di fase
p = corsa('bordi', SON, campione(100, v1) + campione(110, v2))
f1 = righe(p, ['?', '10'])
vero(len(f1) == 1 and 'PARZIALE(inizio traccia)' in f1[0], 'prima finestra PARZIALE: %r' % f1)
fl = righe(p, ['20', '30', '10'])
vero(len(fl) == 1 and 'PARZIALE(END)' in fl[0], 'ultima finestra PARZIALE: %r' % fl)
f2 = righe(p, ['10', '20', '10'])
vero(any('attraversa desktop' in l for l in f2), 'finestra 100..110 attraversa il desktop (105): %r' % f2)
vero('wsl_inizio +22 s (richiesta al task di Windows)' in p.stdout, 'significato di wsl_inizio dichiarato')

# 6. raccolta incompleta: DTrace senza DTRACE_FINE, scaduta, stderr; serie assente
p = corsa('raccolta', SON.replace('DTRACE_FINE\n', 'DTRACE_SCADUTO\n'), None, err='dtrace: 3 drops on CPU 1\n')
vero(p.returncode == 0 and 'senza DTRACE_FINE' in p.stdout and 'SCADUTA' in p.stdout and 'stderr di DTrace' in p.stdout
     and 'stats-serie.txt assente' in p.stdout, 'raccolta incompleta: quattro segnalazioni')

# 7. una corsa vera con le sonde v1 (c1/2): uscita 5, niente analisi
q = subprocess.run(['python3', W + '/analisi-wsl-corsa.py', W + '/logs/campagna-wsl-1/corsa2'], capture_output=True, text=True)
vero(q.returncode == 5 and 'non della v2' in q.stdout, 'corsa con le sonde v1: uscita 5')

# 8. una corsa VERA della campagna 3 (c3/1): nessuna segnalazione, campioni tutti completi
q = subprocess.run(['python3', W + '/analisi-wsl-corsa.py', W + '/logs/campagna-wsl-3/corsa1'], capture_output=True, text=True)
open(O + '/c3-corsa1.txt', 'w').write(q.stdout)
r = [l for l in q.stdout.split('\n') if l.startswith('vCPU nella serie') or l.startswith('SEGNALAZIONI')]
print('  info   c3/1: %s' % ' | '.join(r))
vero(q.returncode == 0 and 'vCPU nella serie: vcpu0,vcpu1' in q.stdout, 'c3/1 vera: due vCPU, uscita 0')
print('SUMMARY: %d ok, %d errati' % (nok, nko))
sys.exit(1 if nko else 0)
