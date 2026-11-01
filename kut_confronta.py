#!/usr/bin/env python3
# Claude 24/10/2026 -- parere #45 §7: confronto degli esiti kvm-unit-tests di una fase
# (run-kut-fase.sh, esiti.txt) con il riferimento: per ogni test, l'esito piu' recente nei
# riassunti logs/kut-*-riassunto.txt PRECEDENTI alla sessione (data limite come argomento),
# oppure con un'altra fase (seconda cartella). Stampa: identici, diversi, nuovi.
# uso: kut_confronta.py <cartella fase> [<cartella fase di riferimento> | --prima AAAAMMGG-HHMMSS]
import sys, os, re, glob
fase = sys.argv[1]
def leggi_esiti(d):
    r = {}
    for l in open(os.path.join(d, "esiti.txt")):
        p = l.split(None, 3)
        if len(p) >= 3 and p[2] in ("PASS", "FAIL", "TIMEOUT") or (len(p) >= 3 and p[2].startswith("ERR")):
            r[(p[0], p[1])] = (p[2], re.sub(r"^rc=\d+\s*", "", p[3].strip() if len(p) > 3 else ""))
    return r
nuovo = leggi_esiti(fase)
rif = {}
if len(sys.argv) > 2 and sys.argv[2] != "--prima":
    rif = leggi_esiti(sys.argv[2]); fonte = sys.argv[2]
else:
    limite = sys.argv[3] if len(sys.argv) > 3 else "20261024-1800"
    fonte = f"riassunti precedenti a {limite}"
    for f in sorted(glob.glob("/mnt/linuxulator2/vm/wsl2/fbsd/logs/kut-*-riassunto.txt")):
        m = re.search(r"kut-(\d{8}-\d{6})-riassunto", f)
        if not m or m.group(1) >= limite.replace("-", "-") and m.group(1)[:13] >= limite[:13]:
            continue
        for l in open(f):
            p = l.split(None, 3)
            if len(p) >= 2:
                rif[p[0]] = (p[1], re.sub(r"^rc=\d+\s*", "", p[3].strip() if len(p) > 3 else ""))
ug = di = nu = 0
print(f"fase: {fase}\nriferimento: {fonte}\n")
for (lista, nome), (v, s) in sorted(nuovo.items()):
    s = re.sub(r"^rc=\d+\s*", "", s)
    r = rif.get((lista, nome)) or rif.get(nome)
    if r is None:
        nu += 1; print(f"  NUOVO    {lista:9} {nome:28} {v:8} {s}")
    elif r[0] == v and re.sub(r"\s+", " ", r[1]) == re.sub(r"\s+", " ", s):
        ug += 1
    else:
        di += 1; print(f"  DIVERSO  {lista:9} {nome:28} ora {v:8} {s}\n           {'':9} {'':28} era {r[0]:8} {r[1]}")
print(f"\nidentici {ug}, diversi {di}, senza riferimento {nu}, totale {len(nuovo)}")
