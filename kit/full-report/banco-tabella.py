#!/usr/bin/env python3
# banco-tabella.py -- Claude 18/11/2026. Legge i risultati di claude-banco / banco-livello.sh in dati-banco/ e stampa
# le tabelle Markdown del rapporto: una colonna per configurazione, media delle ripetizioni (e intervallo min-max).
# I file *.NON-VALIDO-* sono esclusi. I numeri vengono SOLO dai file: niente trascritto a mano.
import glob
import os
import re
import sys

D = sys.argv[1] if len(sys.argv) > 1 else '/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-banco'

# configurazione -> (etichetta breve, motivi dei file)
CONF = [
    ('L0', 'L0 host a riposo', ['banco-L0-riposo-*.txt']),
    ('L0w', 'L0 host, Windows accesa', ['banco-L0-winaccesa-*.txt']),
    ('L1b', 'L1 FreeBSD / bhyve', ['banco-L1-fbsd-bhyve-senza-nesting-*.txt']),
    ('L1bn', 'L1 FreeBSD / bhyve, VMX esposto', ['banco-L1-fbsd-bhyve-con-nesting-*.txt']),
    ('L1u', 'L1 Ubuntu / bhyve', ['banco-L1-ubuntu-bhyve-2*.txt']),
    ('L2bb', 'L2 FreeBSD / bhyve / bhyve', ['banco-L2-fbsd-bhyve-in-bhyve-*.txt']),
    ('L2kb', 'L2 FreeBSD / KVM (Ubuntu) / bhyve', ['banco-L2-fbsd-kvm-in-ubuntu-*.txt']),
    ('L2hq', 'L2 FreeBSD / Hyper-V (WSL2) / QEMU+bhyve', ['banco-L2-wsl-fbsd-2026*.txt']),
    ('L2hb', 'L2 FreeBSD / Hyper-V (WSL2) / bhyve', ['banco-L2-wsl-fbsd-L0bhyve-*.txt']),
    ('L2dq', 'L2 Debian / Hyper-V (WSL2) / QEMU+bhyve', ['banco-L2-wsl-debian-*.txt']),
]
PROVE = [  # (chiave, descrizione, unita', regex, verso: +1 = piu' alto e' meglio)
    ('cpu1', 'CPU, 1 thread', 'Mpassi/s', r'^BANCO cpu1 ([\d.]+)', +1),
    ('cpuN', 'CPU, tutti i thread (per thread)', 'Mpassi/s', r'^BANCO cpuN ([\d.]+) Mpassi/s \((\d+) thread', +1),
    ('syscall', 'chiamata di sistema (getppid)', 'ns', r'^BANCO syscall ([\d.]+)', -1),
    ('fork', 'fork + exec + wait', 'µs', r'^BANCO fork ([\d.]+)', -1),
    ('pipe', 'pipe fra 2 CPU, andata e ritorno (mediana)', 'µs', r'^BANCO pipe ([\d.]+) us', -1),
    ('pipe99', 'pipe, p99', 'µs', r'^BANCO pipe [\d.]+ us mediana, p99 ([\d.]+)', -1),
    ('timer', 'pausa di 1 ms: ritardo mediano', 'µs', r'^BANCO timer (\d+) us', -1),
    ('timer99', 'pausa di 1 ms: ritardo p99', 'µs', r'^BANCO timer \d+ us mediana, p99 (\d+)', -1),
    ('timermax', 'pausa di 1 ms: ritardo massimo', 'µs', r'^BANCO timer .* max (\d+)', -1),
    ('pagine', 'prima scrittura di pagine da 4 KB', 'k/s', r'^BANCO pagine ([\d.]+)', +1),
    ('memcpy', 'memcpy 256 MB, 1 thread', 'GB/s', r'^BANCO memcpy ([\d.]+)', +1),
    ('disco', 'disco: 1 GB scritto + fsync', 'MB/s', None, +1),
    ('scarico', 'rete: host → ospite', 'MB/s', None, +1),
    ('invio', 'rete: ospite → host', 'MB/s', None, +1),
]


def velocita(riga):
    """MB/s da una riga di dd FreeBSD ('(N bytes/sec)') o GNU ('..., 151 MB/s')"""
    m = re.search(r'\((\d+) bytes/sec\)', riga)
    if m:
        return int(m.group(1)) / 1e6
    m = re.search(r'([\d,.]+) ([kMG])B/s', riga)
    if m:
        return float(m.group(1).replace(',', '.')) * {'k': 1e-3, 'M': 1, 'G': 1e3}[m.group(2)]
    return None


def leggi(f):
    t = open(f, errors='replace').read()
    r = {}
    for k, _, _, rx, _ in PROVE:
        if rx:
            m = re.search(rx, t, re.M)
            if m:
                v = float(m.group(1))
                if k == 'cpuN':
                    v = v / int(m.group(2))
                r[k] = v
    for k, chiave in (('disco', 'disco_scrittura'), ('scarico', 'rete_scarico'), ('invio', 'rete_invio')):
        m = re.search(r'^BANCO %s (.+)$' % chiave, t, re.M)
        if m and velocita(m.group(1)) is not None:
            r[k] = velocita(m.group(1))
            # trasferimento arrivato al tetto di 120 s senza finire: valore valido (byte/tempo), lo si segna
            if re.search(r'in 120\.\d+ secs', m.group(1)) and not m.group(1).startswith('1073741824'):
                r[k + '_tetto'] = True
            # 1 GB «esatto in 120 s» = nc rimasto aperto fino al timeout: limite inferiore, non una misura
            if re.search(r'^1073741824 bytes transferred in 120\.0', m.group(1)):
                r[k + '_inferiore'] = True
    return r


def fmt(v):
    if v >= 100:
        return '%.0f' % v
    if v >= 10:
        return '%.1f' % v
    return '%.2f' % v


dati = {}
for k, et, motivi in CONF:
    fs = sorted(f for m in motivi for f in glob.glob(os.path.join(D, m)) if 'NON-VALIDO' not in f)
    dati[k] = [leggi(f) for f in fs]
    dati[k + '#'] = [os.path.basename(f) for f in fs]
# rete a parte: scarico dell'L1 FreeBSD misurato con nc -d (il valore del banco e' un limite inferiore)
extra = glob.glob(os.path.join(D, 'banco-L1-fbsd-bhyve-rete-scarico-*.txt'))
scar_l1 = [velocita(r) for f in extra for r in open(f) if 'bytes/sec' in r]
inv_u = [velocita(r) for f in glob.glob(os.path.join(D, 'banco-L1-ubuntu-bhyve-rete-invio.txt')) for r in open(f)
         if velocita(r)]

print('| prova | unità | ' + ' | '.join(et for _, et, _ in CONF) + ' |')
print('|---|---|' + '---:|' * len(CONF))
print('| ripetizioni | | ' + ' | '.join(str(len(dati[k])) for k, _, _ in CONF) + ' |')
for p, desc, un, _, verso in PROVE:
    celle = []
    for k, _, _ in CONF:
        vv = [r[p] for r in dati[k] if p in r and not r.get(p + '_inferiore')]
        nota = ''
        if p == 'scarico' and k in ('L1b', 'L1bn') and scar_l1:
            vv, nota = scar_l1, ' ⁽ⁿᶜ⁾'
        if p == 'invio' and k == 'L1u' and inv_u:
            vv = inv_u
        if not vv:
            inf = [r[p] for r in dati[k] if r.get(p + '_inferiore')]
            celle.append('≥ %s' % fmt(min(inf)) if inf else '—')
            continue
        if any(r.get(p + '_tetto') for r in dati[k]):
            nota += ' ⁽¹²⁰ˢ⁾'
        m = sum(vv) / len(vv)
        s = fmt(m) if len(vv) == 1 or max(vv) - min(vv) < 0.05 * m else '%s (%s–%s)' % (fmt(m), fmt(min(vv)), fmt(max(vv)))
        celle.append(s + nota)
    print('| %s | %s | %s |' % (desc, un, ' | '.join(celle)))

# rallentamento rispetto all'host a riposo: quante volte piu' lento (1 = come l'host, < 1 = piu' veloce).
# Il timer resta fuori: l'host ha p99/max sporcati dal carico del desktop e i sistemi arrotondano le pause in modo diverso.
print()
print('| volte più lento di L0 a riposo | ' + ' | '.join(et for _, et, _ in CONF[2:]) + ' |')
print('|---|' + '---:|' * (len(CONF) - 2))
for p, desc, un, _, verso in PROVE:
    if p.startswith('timer') or p in ('pipe99', 'disco', 'scarico', 'invio'):
        continue
    b = [r[p] for r in dati['L0'] if p in r]
    if not b:
        continue
    b = sum(b) / len(b)
    celle = []
    for k, _, _ in CONF[2:]:
        vv = [r[p] for r in dati[k] if p in r]
        if not vv:
            celle.append('—')
            continue
        m = sum(vv) / len(vv)
        q = b / m if verso > 0 else m / b
        celle.append('%.0f' % q if q >= 20 else '%.1f' % q)
    print('| %s | %s |' % (desc, ' | '.join(celle)))
print()
for k, et, _ in CONF:
    print('- %s: %s' % (et, ', '.join(dati[k + '#'])))
