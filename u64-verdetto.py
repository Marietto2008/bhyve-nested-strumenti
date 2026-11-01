#!/usr/local/bin/python3
# u64-verdetto.py -- Claude 31/10/2026, parere #167R1 §4-§5. Verdetto della sessione A1 (u64.flat) dalla cartella del
# driver (stato.json, seriale.txt, foto-*.txt). Separato dal runner perche' sia collaudabile su sessioni sintetiche.
#   u64-verdetto.py <cartella del driver>
# Uscita: 0 MODELLO (completa, nativa, 0 contrari); 1 CONTRARIO_AL_MODELLO (completa, nativa: un DATO);
#         3 NON_NATIVA (completa, ma emulazione o nested page fault nella finestra); 5 INCONCLUSIVO (tutto il resto).
# Il codice QEMU (isa-debug-exit) vale (exit_KUT << 1) | 1: 1 = KUT senza fallimenti, 3 = KUT con fallimenti.
import json, os, re, sys

CASI_ATTESI = 28
CONTATORI = ('vm exits for instruction emulation', 'vm exits due to nested page fault')

def main():
	d = sys.argv[1]
	motivi = []
	def no(m):
		motivi.append(m)
	try:
		st = json.load(open(os.path.join(d, 'stato.json')))
	except Exception as e:
		print('INCONCLUSIVO: stato.json illeggibile (%r)' % e)
		return 5
	if not st.get('valida'):
		no('sessione del driver NON valida: %s' % '; '.join(st.get('errori', [])))
	if st.get('timeout'):
		no('TIMEOUT')
	righe = []
	try:
		for l in open(os.path.join(d, 'seriale.txt')):
			righe.append(l.rstrip('\n').split(' ', 1)[1] if ' ' in l else '')
	except Exception as e:
		no('seriale illeggibile (%r)' % e)
	att = [r for r in righe if r.startswith('U64 ATTESI casi=')]
	if len(att) != 1 or att[0] != 'U64 ATTESI casi=%d' % CASI_ATTESI:
		no('riga ATTESI assente, doppia o diversa da %d: %r' % (CASI_ATTESI, att))
	casi = {}
	for r in righe:
		m = re.match(r'U64 CASO (\d+) .* -> (MODELLO|CONTRARIO_AL_MODELLO)$', r)
		if r.startswith('U64 CASO ') and not m:
			no('riga CASO malformata: %r' % r[:80])
		if m:
			n = int(m.group(1))
			if n in casi:
				no('caso %d duplicato' % n)
			casi[n] = m.group(2)
	if sorted(casi) != list(range(1, CASI_ATTESI + 1)):
		no('casi presenti %d, attesi 1..%d univoci' % (len(casi), CASI_ATTESI))
	fine = [r for r in righe if r.startswith('U64 FINE ')]
	contr = sum(1 for v in casi.values() if v != 'MODELLO')
	if len(fine) != 1:
		no('record finale assente o doppio: %d' % len(fine))
	else:
		m = re.match(r'U64 FINE casi=(\d+) modello=(\d+) contrari=(\d+)$', fine[0])
		if not m:
			no('record finale malformato: %r' % fine[0])
		else:
			x, mo, c = map(int, m.groups())
			if x != CASI_ATTESI or mo + c != x or c != contr or x != len(casi):
				no('record finale incoerente: %r (casi letti %d, contrari letti %d)' % (fine[0], len(casi), contr))
	if 'U64 CHIUSO' not in righe:
		no('manca U64 CHIUSO (la chiusura dopo la fotografia finale)')
	if any(r.startswith('U64 PREREQ') or r.startswith('U64 NESSUN VIA') or r.startswith('U64 CHIUSURA MANCATA')
	    for r in righe):
		no('prerequisito o stretta di mano fallita')
	# fotografie: una per evento, rc 0, ogni contatore una volta e numerico
	foto = {}
	for r in st.get('regole', []):
		if r.get('foto'):
			foto[r['testo']] = r
	val = {}
	for ev in ('U64 PRONTO', 'U64 FINE casi='):
		r = foto.get(ev)
		if not r or r.get('stato') != 'fatta' or str(r.get('foto_rc')) != '0' or not r.get('foto_file'):
			no('fotografia per %r assente o fallita' % ev)
			continue
		try:
			testo = open(r['foto_file']).read()
		except Exception as e:
			no('fotografia %r illeggibile (%r)' % (ev, e))
			continue
		if ('# evento: %s\n' % ev) not in testo:
			no('fotografia %r senza l\'evento giusto' % ev)
		for c in CONTATORI:
			l = [x for x in testo.split('\n') if x.strip().startswith(c)]
			if len(l) != 1 or not re.match(r'^\d+$', l[0].split()[-1]):
				no('contatore %r assente, doppio o non numerico in %r' % (c, ev))
			else:
				val[(ev, c)] = int(l[0].split()[-1])
	rc = st.get('qemu_rc')
	if rc not in (1, 3):
		no('codice QEMU %r: non e\' un\'uscita KUT (1 o 3)' % rc)
	elif (rc == 1) != (contr == 0):
		no('codice QEMU %d incoerente con %d contrari' % (rc, contr))
	if motivi:
		print('INCONCLUSIVO: ' + ' | '.join(motivi))
		return 5
	delta = {c: val[('U64 FINE casi=', c)] - val[('U64 PRONTO', c)] for c in CONTATORI}
	if any(delta.values()):
		print('NON_NATIVA: nella finestra %s' % ', '.join('%s +%d' % (c, v) for c, v in delta.items()))
		return 3
	if contr:
		print('CONTRARIO_AL_MODELLO: %d casi su %d (sessione completa e nativa: e\' un DATO)' % (contr, len(casi)))
		return 1
	print('MODELLO: %d casi, 0 contrari, finestra nativa (+0 +0): U64_NATIVE_DATA_ACCESS_OBSERVED' % len(casi))
	return 0

if __name__ == '__main__':
	sys.exit(main())
