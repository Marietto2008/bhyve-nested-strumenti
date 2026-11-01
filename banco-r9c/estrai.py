#!/usr/local/bin/python3
# estrai.py -- Claude 31/10/2026, stadio 10 (R9 e chiamanti). Dal sorgente VERO vmm_instruction_emul.c estrae, senza
# modificarle, la tabella size2mask e le definizioni delle funzioni indicate (stile FreeBSD: tipo sulla riga prima del
# nome, nome a inizio riga), per parentesi graffe bilanciate.
import re, sys
src = open(sys.argv[1]).read()
m = re.search(r'^static uint64_t size2mask\[\] = \{.*?^\};\n', src, re.M | re.S)
if not m:
	sys.exit('size2mask non trovata')
print(m.group(0))
for nome in sys.argv[2:]:
	m = re.search(r'^([^\n]+)\n%s\(' % re.escape(nome), src, re.M)
	if not m:
		sys.exit('definizione di %s non trovata' % nome)
	i = src.index('{', m.end()); d = 0
	for j in range(i, len(src)):
		if src[j] == '{': d += 1
		elif src[j] == '}':
			d -= 1
			if d == 0: break
	print(src[m.start():j + 1] + '\n')
