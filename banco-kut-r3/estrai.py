#!/usr/local/bin/python3
# estrai.py -- Claude 31/10/2026, #169 R3. Estrae dal sorgente VERO della KUT le definizioni delle funzioni indicate
# (firma + corpo, per parentesi bilanciate) e le stampa nell'ordine dato. Nessuna modifica al testo.
import re, sys
src = open(sys.argv[1]).read()
for nome in sys.argv[2:]:
	m = re.search(r'^static [a-z0-9_ *]+\b%s\(([^)]*)\)\n\{' % re.escape(nome), src, re.M)
	if not m:
		sys.exit('definizione di %s non trovata' % nome)
	i = src.index('{', m.end() - 1); d = 0
	for j in range(i, len(src)):
		if src[j] == '{': d += 1
		elif src[j] == '}':
			d -= 1
			if d == 0: break
	print(src[m.start():j + 1] + '\n')
