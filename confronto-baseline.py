#!/usr/local/bin/python3
# confronto-baseline.py -- Claude 30/10/2026, parere #149 §3. Confronto delle righe del guest (CASE, L1, XINFO, EPT,
# LIV, MAP) di una sessione con la sua baseline, con un DOMINIO DI NORMALIZZAZIONE esplicito.
#   - La corrispondenza fra le pagine dinamiche si ricava SOLO dalle righe di allocazione di ciascuna sessione: MAP (d, T,
#     pagina di pdeaddr, pagina di pteaddr) e la PRIMA riga LIV (pagine puntate dalle voci pml4/pdpt/pde/pte, valori
#     "prima"). Mai dalle differenze stesse.
#   - Si traducono solo i valori esadecimali la cui pagina (v & ~0xfff) sta nel dominio; i 12 bit bassi restano. Tutto il
#     resto e' confrontato COSI' COM'E': MMIO fissi (es. 0xfec00000), reason, qual, viol, dwr, ripadv, paddr, bit A/D
#     (stanno nei 12 bit bassi), GLA, RIP, ordine delle righe.
#   - La corrispondenza deve essere una biiezione; altrimenti INCONCLUSIVE.
# Uso: confronto-baseline.py <combinato baseline> <combinato sessione>
# Uscita 0 = identiche nel dominio; 1 = differenze; 2 = corrispondenza non dimostrabile (INCONCLUSIVE).
import re, sys

TIPI = ('CASE', 'L1', 'XINFO', 'EPT', 'LIV', 'MAP')

def righe(p):
	return [r.strip() for r in open(p, errors='replace') if r.strip().split(' ', 1)[0] in TIPI]

def pagine_allocate(rr):
	"""{nome: pagina} dalle righe di allocazione della sessione."""
	p = {}
	m = next((r for r in rr if r.startswith('MAP ')), None)
	if m is None:
		return None
	kv = dict(x.split('=', 1) for x in m.split()[1:] if '=' in x)
	for k in ('d', 'T'):
		if k in kv:
			p['MAP.' + k] = int(kv[k], 16) & ~0xfff
	for k in ('pdeaddr', 'pteaddr'):
		if k in kv:
			p['MAP.' + k] = int(kv[k], 16) & ~0xfff
	liv = next((r for r in rr if r.startswith('LIV ')), None)
	if liv is not None:
		for x in liv.split()[1:]:
			k, v = x.split('=', 1)
			p['LIV.' + k] = int(v.split('>')[0], 16) & ~0xfff
	return p

def main():
	b, n = righe(sys.argv[1]), righe(sys.argv[2])
	pb, pn = pagine_allocate(b), pagine_allocate(n)
	if pb is None or pn is None or set(pb) != set(pn):
		print('INCONCLUSIVE: righe di allocazione assenti o diverse (%s / %s)' % (sorted(pb or {}), sorted(pn or {})))
		return 2
	mappa = {}
	for k in pb:
		if pn[k] in mappa and mappa[pn[k]] != pb[k]:
			print('INCONCLUSIVE: la pagina %x della sessione corrisponde a due pagine della baseline' % pn[k]); return 2
		mappa[pn[k]] = pb[k]
	if len(set(mappa.values())) != len(mappa):
		print('INCONCLUSIVE: corrispondenza non iniettiva %s' % mappa); return 2
	print('dominio (sessione -> baseline), da MAP e prima LIV:')
	for k in sorted(pb):
		print('  %-12s %x -> %x' % (k, pn[k], pb[k]))
	tradotti = [0]
	def traduci(mt):
		v = int(mt.group(0), 16)
		if (v & ~0xfff) in mappa:
			tradotti[0] += 1
			return '%x' % (mappa[v & ~0xfff] | (v & 0xfff))
		return mt.group(0)
	def norm(r):
		# solo i valori dopo '=' o '>' (mai nomi di campo); token esadecimali interi
		return re.sub(r'(?<=[=>])[0-9a-f]+\b', traduci, r)
	nn = [norm(r) for r in n]
	diverse = [(x, y) for x, y in zip(b, nn) if x != y]
	extra = abs(len(b) - len(nn))
	print('righe %d/%d, valori tradotti %d, diverse %d' % (len(b), len(nn), tradotti[0], len(diverse) + extra))
	for x, y in diverse[:10]:
		print('  base: %s\n  ora : %s' % (x, y))
	return 0 if not diverse and not extra else 1

if __name__ == '__main__':
	sys.exit(main())
