#!/usr/bin/env python3
# tabella-kvm.py -- Claude 11/11/2026: tabella per giro del giro lungo KVM dai file di bpftrace (istantanee al minuto)
# e dai file ciclo-*.txt (orari di fine giro). Episodi VERI di FreeBSD = classi 0 e 2 (rientro a rip0+6 o a rip0);
# la classe 1 («altro») e' l'artefatto delle false coppie (vedi esiti.md 11/11 10:10).
# 11/11 12:35: due serie di contatori, ognuna da zero: episodi-20261111-0306.txt (v1, morta alle 10:30:14) ed
# episodi2-1043.txt (v2, filtro sulla pagina 0xffffffff8120b000, dalle 12:17). Per ogni giro: delta nella serie che lo
# copre, minuti coperti e svuotamenti stimati nella finestra coperta (ritmo del giro: ok / durata dello svuotamento).
import re, glob
D = '/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-kvm/'
sec = lambda t: int(t[:2]) * 3600 + int(t[3:5]) * 60 + int(t[6:8])
def serie(nome):
    snap, cur = [], None
    for l in open(D + nome, errors='replace'):
        m = re.match(r'(\d\d:\d\d:\d\d) @episodi: (\d+)', l)
        if m:
            cur = {'ep': int(m.group(2))}; snap.append((sec(m.group(1)), cur)); continue
        m = re.match(r'@e0c\[(\d), (\d)\]: (\d+)', l)
        if m and cur is not None:
            cur['c%s%s' % (m.group(1), m.group(2))] = int(m.group(3))
    # contatori a zero un minuto prima della prima istantanea (bpftrace stampa ogni 60 s dall'avvio)
    return [(snap[0][0] - 60, {})] + snap
S = [serie('episodi-20261111-0306.txt'), serie('episodi2-1043.txt')]
giri = []          # (inizio, fine, svuotamenti, inizio svuota, fine svuota)
for f in sorted(glob.glob(D + 'ciclo-20261111-*.txt')):
    ini = None
    for l in open(f, errors='replace'):
        m = re.match(r'(\d\d:\d\d:\d\d) giro \d+ di', l)
        if m: ini = m.group(1)
        m = re.match(r'(\d\d:\d\d:\d\d) giro \d+: .*nessun panic.*ok=(\d+) \| (\S+)', l)
        if m:
            g = open(m.group(3), errors='replace').read()
            a = re.search(r'(\d\d:\d\d:\d\d) svuota-vmmem avviato', g).group(1)
            b = re.search(r'^fine (\d\d:\d\d:\d\d)', g, re.M).group(1)
            giri.append((sec(ini), sec(m.group(1)), int(m.group(2)), sec(a), sec(b)))
def finestra(a, b):  # (istantanea iniziale, istantanea finale) della serie che copre [a, b], o None
    for s in S:
        s0 = [x for x in s if x[0] <= a] or [s[0]]
        s1 = [x for x in s if x[0] <= b]
        if s1 and s1[-1][0] > s0[-1][0]: return s0[-1], s1[-1]
    return None
g = lambda s, k: s.get(k, 0)
vero = lambda s: g(s, 'c00') + g(s, 'c01') + g(s, 'c20') + g(s, 'c21')
hm = lambda t: '%02d:%02d' % (t // 3600, t // 60 % 60)
print('| giro | orario | coperto da bpftrace | episodi veri | per min coperto | svuotamenti (giro) | svuot. nella finestra | fermi | fermi/svuot. | fermo+evento | panic |')
print('|---|---|---|---|---|---|---|---|---|---|---|')
tot = [0, 0, 0, 0, 0, 0]
for i, (a, b, sv, va, vb) in enumerate(giri, 1):
    w = finestra(a, b)
    tot[4] += sv
    if w is None:
        print('| %d | %s-%s | no | — | — | %d | — | — | — | — | no |' % (i, hm(a), hm(b), sv)); continue
    (t0, s0), (t1, s1) = w
    ca, cb = max(a, t0), min(b, t1)
    ev = vero(s1) - vero(s0); fe = g(s1, 'c20') - g(s0, 'c20'); fev = g(s1, 'c21') - g(s0, 'c21')
    swin = sv * max(0, min(cb, vb) - max(ca, va)) / (vb - va)
    pieno = ca - a < 120 and b - cb < 120
    per = ev / 20e6 if pieno else ev / ((cb - ca) / 60) / 1e6   # giro pieno: 20 min di claude-lag
    print('| %d | %s-%s | %s | %s | %.2f M | %d | %.0f | %d | %.1f | %d | no |' % (i, hm(a), hm(b),
          'si' if pieno else '%s-%s' % (hm(ca), hm(cb)), format(ev, ',').replace(',', '.'), per, sv, swin, fe,
          fe / swin if swin else 0, fev))
    tot[0] += ev; tot[1] += swin; tot[2] += fe; tot[3] += fev; tot[5] += 1
print('| **totale %d giri** | | %d con contatori | **%s** | | **%d** | **%.0f** | **%d** | **%.1f** | **%d** | **0** |' % (len(giri),
      tot[5], format(tot[0], ',').replace(',', '.'), tot[4], tot[1], tot[2], tot[2] / tot[1], tot[3]))
