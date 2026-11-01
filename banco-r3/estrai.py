# estrai.py -- Claude 30/10/2026 (#158 B4d). Estrae la DEFINIZIONE (non il prototipo) di ciascuna funzione:
# la riga del tipo che precede "nome(" a inizio riga e il corpo fino alla prima "}" a inizio riga.
# Uso: estrai.py <file.c> <nome>...   Esce 1 se una funzione manca o e' ambigua.
import sys, re
src = open(sys.argv[1]).read().split('\n')
ok = True
for n in sys.argv[2:]:
    trovate = []
    for i, l in enumerate(src):
        if not l.startswith(n + '('):
            continue
        j = i
        while '{' not in src[j] and ';' not in src[j] and j < i + 6:
            j += 1
        if src[j].rstrip().endswith(';'):
            continue			# prototipo
        k = j
        while not src[k].startswith('}'):
            k += 1
        trovate.append((i, k))
    if len(trovate) != 1:
        print('#error funzione %s: %d definizioni' % (n, len(trovate))); ok = False; continue
    i, k = trovate[0]
    print('/* --- %s:%d */' % (sys.argv[1].split('/sys/')[-1], i + 1))
    print('\n'.join(src[i - 1:k + 1])); print()
sys.exit(0 if ok else 1)
