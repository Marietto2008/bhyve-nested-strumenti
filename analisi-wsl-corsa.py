#!/usr/local/bin/python3
# analisi-wsl-corsa.py -- Claude 01/11/2026. Lettura (solo lettura) di una corsa della campagna WSL con le sonde v2:
# sonde.txt (finestre "F <epoca>", "L2 <motivo> <n>", "RIF <motivo> <n>"), stats-serie.txt ("T <epoca>" e le righe
# di bhyvectl --get-stats per vCPU) e fasi.txt (avvio, desktop, wsl_inizio, wsl_fine, spegnimento).
# Serve a separare "L2 lento" (ritmo costante, stessi motivi) da "L2 in un giro" (un motivo che domina una fase).
#
# Revisione 2 (parere #171 di Astra, par. 3): i due strumenti NON si allineano per finzione. Revisione 3 (#172): una riga
# doppia invalida il campione; vCPU attese da serie-attese.txt (configurazione), non dedotte; "TF" = fine del campione.
#  - Le finestre DTrace e gli intervalli dei contatori sono stampati SEPARATI, ciascuno coi suoi estremi e la sua
#    durata; i contatori come TASSO al secondo sull'intervallo vero fra due campioni.
#  - Ogni campione dei contatori deve avere TUTTE le vCPU viste nella corsa e ogni contatore richiesto: altrimenti il
#    campione e' INCOMPLETO e gli intervalli che lo toccano valgono NA. Vengono segnalati vCPU mancanti, righe doppie,
#    contatori assenti e delta NEGATIVI (mai stampati come numeri).
#  - La prima finestra DTrace (inizio = avvio della traccia, non noto) e l'ultima (chiusa da END) sono PARZIALI; una
#    finestra o un intervallo che attraversa un cambio di fase e' marcato.
#  - I marcatori del runner hanno il loro significato: wsl_inizio = richiesta al task di Windows (non l'avvio nel
#    guest), wsl_fine = fine del POLLING (anche a tentativi esauriti). L'esito dell'ospite sta in esito.txt e nel
#    verdetto, non qui.
#  - Completezza della raccolta: DTRACE_FINE assente, DTRACE_SCADUTO, stderr di DTrace non vuoto, righe d'errore
#    nella serie, salti fra i campioni: segnalati in testa. L'uscita 0 di questo programma NON e' un verdetto.
# Uscite: 0 analisi stampata (anche con segnalazioni), 5 niente da analizzare (non v2 o file assenti).
# Uso: analisi-wsl-corsa.py <cartella della corsa>
import os, re, sys

MOTIVI = {0: 'EXC/NMI', 1: 'EXTINT', 2: 'TRIPLE', 7: 'INTWIN', 8: 'NMIWIN', 9: 'TASKSW', 10: 'CPUID', 12: 'HLT',
          13: 'INVD', 14: 'INVLPG', 15: 'RDPMC', 16: 'RDTSC', 18: 'VMCALL', 19: 'VMCLEAR', 20: 'VMLAUNCH',
          21: 'VMPTRLD', 23: 'VMREAD', 24: 'VMRESUME', 25: 'VMWRITE', 28: 'CR', 29: 'DR', 30: 'IO', 31: 'RDMSR',
          32: 'WRMSR', 33: 'ENTRYFAIL', 36: 'MWAIT', 37: 'MTF', 39: 'MONITOR', 40: 'PAUSE', 43: 'TPR', 44: 'APICACC',
          45: 'EOI', 46: 'GDTR/IDTR', 47: 'LDTR/TR', 48: 'EPTVIOL', 49: 'EPTMISC', 50: 'INVEPT', 51: 'RDTSCP',
          52: 'PREEMPT', 53: 'INVVPID', 54: 'WBINVD', 55: 'XSETBV', 56: 'APICWR', 57: 'RDRAND', 58: 'INVPCID',
          59: 'VMFUNC', 61: 'RDSEED', 63: 'XSAVES', 64: 'XRSTORS'}
SERIE = ['ingressi in L2', "exit riflesse all'L1", 'exit nested gestite nello slow path',
         'vm exits for instruction emulation', 'immediate exit armate da L0', 'vm exits due to interrupt window opening',
         'vcpu migration across host cpus']
CORTI = ['L2in', 'rifl', 'slow', 'emul', 'immx', 'intw', 'migr']
SIGNIFICATO = {'wsl_inizio': 'richiesta al task di Windows', 'wsl_fine': 'il runner ha visto la riga codice: fine del polling',
               'wsl_esaurito': 'tentativi del runner finiti SENZA la riga codice'}


def nome(m):
	return MOTIVI.get(m, str(m))


def leggi(d, f):
	try:
		return open(os.path.join(d, f), errors='replace').read()
	except OSError:
		return None


def finestre(testo):
	"""[(epoca di fine, {motivo: n} L2, {motivo: n} RIF)] nell'ordine del file"""
	out = []
	for l in testo.split('\n'):
		m = re.match(r'^F (\d+)$', l)
		if m:
			out.append((int(m.group(1)), {}, {}))
			continue
		m = re.match(r'^(L2|RIF) (\d+) (\d+)$', l)
		if m and out:
			out[-1][1 if m.group(1) == 'L2' else 2][int(m.group(2))] = int(m.group(3))
	return out


def campioni(testo, avvisi):
	"""[(epoca d'inizio, {(vcpu, contatore): valore}, n righe d'errore, chiavi doppie, epoca di fine o None)].
	Rev. 3 (parere #172): una riga doppia INVALIDA il campione (non si sovrascrive); "TF <epoca>" = fine della
	lettura (le vCPU si leggono in successione)."""
	out = []
	for l in testo.split('\n'):
		m = re.match(r'^T (\d+)$', l)
		if m:
			out.append([int(m.group(1)), {}, 0, set(), None])
			continue
		m = re.match(r'^TF (\d+)$', l)
		if m and out:
			out[-1][4] = int(m.group(1))
			continue
		if not out or not l.strip():
			continue
		m = re.match(r'^(vcpu\d+) (.*?)\s+(\d+)$', l)
		if m:
			k = (m.group(1), m.group(2).strip())
			if k[1] in SERIE:
				if k in out[-1][1]:
					avvisi.append('campione T %d: riga doppia per %s %s: campione INVALIDO' % (out[-1][0], k[0], k[1]))
					out[-1][3].add(k)
				out[-1][1][k] = int(m.group(3))
		elif not re.match(r'^vcpu\d+ vcpu\d+ stats:$', l.strip()):
			out[-1][2] += 1		# ne' un contatore ne' l'intestazione: tipicamente un errore di bhyvectl
	return out


def completo(c, vcpu):
	return not c[3] and all((v, k) in c[1] for v in vcpu for k in SERIE)


def fase(t, fasi):
	nomef = 'prima'
	for n, e in sorted(fasi.items(), key=lambda x: x[1]):
		if t >= e:
			nomef = n
	return nomef


def attraversa(a, b, fasi):
	return [n for n, e in fasi.items() if a < e <= b]


def main():
	d = sys.argv[1]
	so = leggi(d, 'sonde.txt')
	if so is None or 'DTRACE_ATTIVO sonde-wsl-v2' not in so:
		print('sonde.txt assente o non della v2: niente da analizzare'); return 5
	avvisi = []
	# --- completezza della raccolta
	if 'DTRACE_FINE' not in so:
		avvisi.append('traccia DTrace senza DTRACE_FINE: l\'ultima finestra puo\' mancare')
	if 'DTRACE_SCADUTO' in so:
		avvisi.append('traccia DTrace SCADUTA prima della fine della corsa')
	se = leggi(d, 'sonde-err.txt')
	if se is None:
		avvisi.append('sonde-err.txt assente')
	elif se.strip():
		avvisi.append('stderr di DTrace non vuoto: %r' % se.strip()[:100])
	fasi = {}
	for l in (leggi(d, 'fasi.txt') or '').split('\n'):
		p = l.split()
		if len(p) == 2 and p[1].isdigit():
			fasi[p[0]] = int(p[1])
	if 'avvio' not in fasi:
		avvisi.append('fasi.txt senza "avvio": tempi assoluti (epoca)')
	t0 = fasi.get('avvio', 0)
	sr = leggi(d, 'stats-serie.txt')
	if sr is None:
		avvisi.append('stats-serie.txt assente: nessun intervallo dei contatori')
		sr = ''
	cs = campioni(sr, avvisi)
	# vCPU ATTESE dalla configurazione (serie-attese.txt, scritto dal runner da macchina.conf), non da quelle viste
	att = re.findall(r'^vcpu (\d+)$', leggi(d, 'serie-attese.txt') or '', re.M)
	if len(att) == 1:
		vcpu = ['vcpu%d' % i for i in range(int(att[0]))]
		extra = sorted({v for c in cs for (v, _) in c[1]} - set(vcpu))
		if extra:
			avvisi.append('vCPU non attese nella serie: %s' % ','.join(extra))
	else:
		vcpu = sorted({v for c in cs for (v, _) in c[1]})
		avvisi.append('vCPU attese NON dichiarate (serie-attese.txt): dedotte da quelle viste (%s)' % (','.join(vcpu) or '-'))
	for c in cs:
		if c[4] is not None and c[4] - c[0] > 2:
			avvisi.append('campione T %d: lettura durata %d s (le vCPU si leggono in successione)' % (c[0], c[4] - c[0]))
	for c in cs:
		manc = sorted({v for v in vcpu if not any((v, k) in c[1] for k in SERIE)})
		if manc:
			avvisi.append('campione T %d: vCPU mancante %s' % (c[0], ','.join(manc)))
		elif not completo(c, vcpu):
			avvisi.append('campione T %d: contatori assenti %s' % (c[0], sorted({'%s %s' % (v, k) for v in vcpu
			              for k in SERIE if (v, k) not in c[1]})[:3]))
		if c[2]:
			avvisi.append('campione T %d: %d righe non riconosciute o d\'errore' % (c[0], c[2]))
	for a, b in zip(cs, cs[1:]):
		if b[0] - a[0] > 30:
			avvisi.append('salto di %d s fra i campioni T %d e T %d' % (b[0] - a[0], a[0], b[0]))
	print('analisi-wsl-corsa rev. 3: %s' % d)
	print('fasi: ' + ', '.join('%s +%d s%s' % (n, e - t0, ' (%s)' % SIGNIFICATO[n] if n in SIGNIFICATO else '')
	      for n, e in sorted(fasi.items(), key=lambda x: x[1])))
	print('vCPU nella serie: %s; campioni: %d (%d completi)' % (','.join(vcpu) or '-', len(cs),
	      sum(1 for c in cs if completo(c, vcpu))))
	print('SEGNALAZIONI: %d' % len(avvisi))
	for a in avvisi[:40]:
		print('  ! ' + a)
	if len(avvisi) > 40:
		print('  ! ... altre %d' % (len(avvisi) - 40))

	# --- finestre DTrace: estremi propri
	fw = finestre(so)
	print('\nFINESTRE DTRACE (estremi = due righe "F" consecutive; la prima e l\'ultima sono PARZIALI)')
	print('%7s %7s %4s %-11s %9s %-40s %8s  %s' % ('da(s)', 'a(s)', 'dur', 'fase', 'uscite L2', 'motivi principali (L2)',
	      'riflesse', 'note'))
	totali = {}
	for i, (ep, l2, rif) in enumerate(fw):
		da = fw[i - 1][0] if i > 0 else None
		note = []
		if i == 0:
			note.append('PARZIALE(inizio traccia)')
		if i == len(fw) - 1:
			note.append('PARZIALE(END)')
		if da is not None and attraversa(da, ep, fasi):
			note.append('attraversa ' + '+'.join(attraversa(da, ep, fasi)))
		for m, n in l2.items():
			totali[m] = totali.get(m, 0) + n
		tot = sum(l2.values())
		top = sorted(l2.items(), key=lambda x: -x[1])[:3]
		ts = ', '.join('%s %d%%' % (nome(m), 100 * n // tot) for m, n in top) if tot else '-'
		print('%7s %7d %4s %-11s %9d %-40s %8d  %s' % ('?' if da is None else da - t0, ep - t0,
		      '?' if da is None else ep - da, fase(ep, fasi), tot, ts[:40], sum(rif.values()), ' '.join(note)))
	tt = sum(totali.values())
	if tt:
		print('motivi sull\'intera traccia: ' + ', '.join('%s %d (%.1f%%)' % (nome(m), n, 100.0 * n / tt)
		      for m, n in sorted(totali.items(), key=lambda x: -x[1])[:10]))

	# --- intervalli dei contatori: estremi propri, tassi al secondo, per vCPU e totale
	print('\nINTERVALLI DEI CONTATORI (fra due campioni consecutivi; tassi al secondo; NA = campione incompleto o delta '
	      'negativo)')
	print('%7s %7s %4s %-11s %-6s %s  %s' % ('da(s)', 'a(s)', 'dur', 'fase', 'vCPU', ' '.join('%8s' % c for c in CORTI),
	      'note'))
	for a, b in zip(cs, cs[1:]):
		dur = b[0] - a[0]
		note = []
		if attraversa(a[0], b[0], fasi):
			note.append('attraversa ' + '+'.join(attraversa(a[0], b[0], fasi)))
		ok = completo(a, vcpu) and completo(b, vcpu) and dur > 0
		if not ok:
			note.append('NA: campione incompleto' if dur > 0 else 'NA: durata %d' % dur)
		for v in vcpu + ['tot']:
			cel = []
			for k in SERIE:
				if not ok:
					cel.append('NA'); continue
				vs = vcpu if v == 'tot' else [v]
				dlt = sum(b[1][(x, k)] - a[1][(x, k)] for x in vs)
				neg = any(b[1][(x, k)] < a[1][(x, k)] for x in vs)
				if neg:
					cel.append('NA')
					note.append('delta NEGATIVO %s %s' % (v, k))
				else:
					cel.append('%.0f' % (dlt / dur))
			print('%7d %7d %4d %-11s %-6s %s  %s' % (a[0] - t0, b[0] - t0, dur, fase(b[0], fasi), v,
			      ' '.join('%8s' % x for x in cel), ' '.join(sorted(set(note))) if v == 'tot' else ''))
	return 0


if __name__ == '__main__':
	sys.exit(main())
