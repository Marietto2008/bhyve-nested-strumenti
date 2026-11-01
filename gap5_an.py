#!/usr/bin/env python3
# Claude 24/10/2026 -- parere #42: analisi della prova A/B/A su autoMemoryReclaim (run-gap5.sh).
# Tutto in ora dell'host: Linux con le righe SYNC di gapmon, Windows coi marcatori UDP di
# hvperf.ps1 (hvperf-sync<F>.txt). Per ogni fase SEPARATAMENTE (parere #42 §8):
#  1. verifiche preliminari (page_reporting_order, messaggi di hv_balloon / free page reporting);
#  2. buchi; hypercall della radice, flush, INVEPT, ingressi WSL per passo del ciclo
#     (dd, sha, sync, drop, rilettura) e dentro/fuori dai buchi;
#  3. memoria: Linux (memmon: MemFree, Cached, pgfree), Windows (working set di vmmem),
#     partizione WSL (contatori Hyper-V: pagine GPA, frantumate/ricombinate, flush TLB);
#  4. permutazione circolare DENTRO la fase (0x4b contro copertura dei buchi);
#  5. tratti TSC e uscite per finestra (rootcall5.d, righe C/V) e ragioni delle uscite dell'L1
#     (exitrsn.d, solo nei cicli in cui era accesa); costo della sonda: cicli ON contro OFF.
# uso: gap5_an.py <cartella della corsa>
import re, sys, os, csv, bisect, random, datetime, statistics as st
from collections import defaultdict
d = sys.argv[1]
FASI = [F for F in ("A1", "B", "A2") if os.path.exists(f"{d}/gapmem-{F}.log")]
TSC = 3600018355
PASSI = ["dd", "sha", "sync", "drop", "rilettura"]

def offset_linux(F):
    off = []
    for l in open(f"{d}/gapmem-gapmon-{F}.txt", errors="replace"):
        if l.startswith("SYNC"):
            p = list(map(int, l.split()[1:]))
            if p[1] - p[0] < 5e6: off.append((p[0], p[3] - (p[0] + p[1]) / 2))
    return off
def a_host(off, t_ns):
    return (t_ns + min(off, key=lambda x: abs(x[0] - t_ns))[1]) / 1e9

def buchi(F, off):
    G = []
    for l in open(f"{d}/gapmem-gapmon-{F}.txt", errors="replace"):
        m = re.match(r"BUCO (\d+) ms da mono=\d+ real=(\d+) a mono=\d+ real=(\d+)", l)
        if m: G.append((a_host(off, int(m.group(2))), a_host(off, int(m.group(3))), int(m.group(1))))
    return G

def cicli(F, off):
    """passi: lista (inizio, fine, ciclo, passo) in ora host; solo cicli completi"""
    ev = []
    for l in open(f"{d}/gapmem-{F}.log", errors="replace"):
        m = re.match(r"CICLO (\S+) (\S+) ([\d.]+)", l)
        if m: ev.append((m.group(1), m.group(2), a_host(off, int(float(m.group(3)) * 1e9))))
    P = []
    for i in range(len(ev) - 1):
        c, p, t = ev[i]
        if p in PASSI and ev[i + 1][0] == c: P.append((t, ev[i + 1][2], c, p))
    return P, ev

def leggi_rc():
    W = []; cur = None
    for l in open(f"{d}/rc.txt", errors="replace"):
        if l.startswith("T "):
            cur = {"t": int(l.split()[1]) / 1e9, "hc": defaultdict(int), "ing": 0, "inv": 0, "invr": 0}
            W.append(cur); continue
        if cur is None: continue
        m = re.match(r"\s+hcall (0x[0-9a-f]+) n (\d+)", l)
        if m: cur["hc"][int(m.group(1), 16)] += int(m.group(2)); continue
        m = re.match(r"\s+vp \S+ ing (\d+)", l)
        if m: cur["ing"] += int(m.group(1)); continue
        m = re.match(r"\s+invept (\S+) tipo \d+ n (\d+)", l)
        if m: cur["inv" if m.group(1) == "altro" else "invr"] += int(m.group(2)); continue
        m = re.match(r"\s+C (\d+) (\d+)", l)
        if m: cur["C"] = (int(m.group(1)), int(m.group(2))); continue
        m = re.match(r"\s+V([012]) (.*)", l)
        if m: cur["V" + m.group(1)] = list(map(int, m.group(2).split()))
    return W

def leggi_samp():
    B = []; cur = None
    for l in open(f"{d}/samp.txt", errors="replace"):
        if l.startswith("T "): cur = (int(l.split()[1]) / 1e9, []); B.append(cur); continue
        m = re.match(r"\s+v(\d+) (0x[0-9a-f]+|0) guest (\d+) l0 (\d+) fuori (\d+)", l)
        if m and cur: cur[1].append((int(m.group(2), 16), int(m.group(3)), int(m.group(4)), int(m.group(5))))
    return B

def leggi_exr():
    """finestre di exitrsn.d (solo quando accesa): (t, {('l1',r):n, ('radice'|'wsl',r):n})"""
    W = []
    for f in sorted(os.listdir(d)):
        if not f.startswith("exr-") or f == "exr-commutazioni.txt" or not f.endswith(".txt"): continue
        cur = None
        for l in open(f"{d}/{f}", errors="replace"):
            if l.startswith("T "): cur = (int(l.split()[1]) / 1e9, defaultdict(int)); W.append(cur); continue
            m = re.match(r"\s+l1 (\d+) (\d+)", l)
            if m and cur: cur[1][("l1", int(m.group(1)))] += int(m.group(2)); continue
            m = re.match(r"\s+l2 (\S+) (\d+) (\d+)", l)
            if m and cur: cur[1][(m.group(1), int(m.group(2)))] += int(m.group(3)); continue
            m = re.match(r"\s+incoerenti (\d+)", l)
            if m and cur: cur[1][("bad", 0)] += int(m.group(1))
    W.sort(key=lambda x: x[0])
    return W

def commutazioni():
    on = []; t0 = None
    if not os.path.exists(f"{d}/exr-commutazioni.txt"): return on
    for l in open(f"{d}/exr-commutazioni.txt"):
        t, s = l.split()[:2]; t = float(t)
        if s == "ON": t0 = t
        elif t0 is not None: on.append((t0, t)); t0 = None
    return on

def win_offset(F):
    off = []
    p = f"{d}/hvperf-sync{F}.txt"
    if not os.path.exists(p): return None
    for l in open(p, errors="replace"):
        x = l.split()
        if len(x) >= 6 and x[0] == "SYNC":
            t1, t4, h = int(x[2]), int(x[3]), int(x[5])
            if t4 - t1 < 5e6: off.append((h - (t1 + t4) / 2) / 1e9)
    return st.median(off) if off else None

def sovrapp(a, b, G):
    return sum(max(0, min(b, g[1]) - max(a, g[0])) for g in G)

RC = leggi_rc(); RT = [w["t"] for w in RC]
SA = leggi_samp(); ST = [b[0] for b in SA]
EX = leggi_exr(); ET = [w[0] for w in EX]
ON = commutazioni()
ROOT = set(int(x, 16) for x in open(f"{d}/radice.txt").read().split()[-2:])
def acceso(t): return any(a <= t <= b for a, b in ON)

def finestre(L, T, a, b):
    i = bisect.bisect_left(T, a + 0.1); j = bisect.bisect_right(T, b)
    return L[i:j]

riass = {}
for F in FASI:
    print(f"\n################ fase {F}")
    for k in ("pre", "post"):
        p = f"{d}/gapmem-{k}-{F}.txt"
        if os.path.exists(p):
            txt = open(p, errors="replace").read()
            m = re.search(r"== page_reporting_order\n(.*)\n", txt)
            print(f"  [{k}] page_reporting_order = {m.group(1) if m else '?'}")
            m = re.search(r"== dmesg \(free page reporting.*?\n(.*?)== meminfo", txt, re.S)
            if m and k == "pre":
                for l in m.group(1).strip().splitlines(): print(f"  [{k}] dmesg: {l}")
            m = re.search(r"== meminfo\n(.*?)== vmstat", txt, re.S)
            if m: print(f"  [{k}] " + " ".join(x.split()[0] + x.split()[1] for x in m.group(1).strip().splitlines()))
    off = offset_linux(F)
    G = buchi(F, off)
    P, ev = cicli(F, off)
    rf = [e for e in ev if e[1] == "dd" and not e[0].startswith("R")]
    gl = sorted(g[2] for g in G)
    tg = [x for x in open(f"{d}/gapmem-{F}.log") if x.startswith("RISCALDAMENTO-FINE")]
    print(f"  buchi {len(G)} (somma {sum(gl)/1000:.1f} s, mediana {st.median(gl) if gl else 0} ms, max {gl[-1] if gl else 0} ms) "
          f"in {len(rf)} cicli di prova")
    # passi del ciclo
    print(f"  {'passo':<10} {'n':>3} {'durata s':>9} {'buchi':>6} {'buco s/s':>8} {'0x4b/s':>8} {'0x03/s':>7} {'INVEPT/s':>9} {'ingr.WSL/s':>10} {'L1g%':>6} {'L2g%':>6}")
    per = defaultdict(lambda: defaultdict(list))
    for a, b, c, p in P:
        if c.startswith("R"): p = "R-" + p
        Wn = finestre(RC, RT, a, b)
        dur = b - a
        if not Wn: continue
        s = lambda k: sum(w["hc"].get(k, 0) for w in Wn) / (len(Wn) / 10)
        x = per[p]
        x["dur"].append(dur); x["buchi"].append(sum(1 for g in G if a <= g[0] < b))
        x["cop"].append(sovrapp(a, b, G) / dur)
        x["4b"].append(s(0x4b)); x["03"].append(s(0x3))
        x["inv"].append(sum(w["inv"] for w in Wn) / (len(Wn) / 10)); x["ing"].append(sum(w["ing"] for w in Wn) / (len(Wn) / 10))
        Cw = [w for w in Wn if "C" in w]
        if len(Cw) > 1:
            span = Cw[-1]["t"] - Cw[0]["t"]
            x["l1g"].append(100 * (Cw[-1]["C"][0] - Cw[0]["C"][0]) / TSC / span / 2)
            x["l2g"].append(100 * (Cw[-1]["C"][1] - Cw[0]["C"][1]) / TSC / span / 2)
        x["on"].append(acceso((a + b) / 2))
    for p in [q for q in PASSI] + ["R-" + q for q in PASSI]:
        x = per.get(p)
        if not x: continue
        m = lambda k: st.mean(x[k]) if x[k] else float("nan")
        print(f"  {p:<10} {len(x['dur']):3d} {m('dur'):9.1f} {sum(x['buchi']):6d} {m('cop'):8.3f} {m('4b'):8.0f} {m('03'):7.0f} {m('inv'):9.0f} {m('ing'):10.0f} {m('l1g'):6.1f} {m('l2g'):6.1f}")
    # dentro / fuori dai buchi nella parte di prova
    if rf:
        t0 = rf[0][2]; t1 = max(g[1] for g in G) + 30 if G else t0 + 480
        Wp = finestre(RC, RT, t0, t1)
        den = [w for w in Wp if sovrapp(w["t"] - 0.1, w["t"], G) > 0.05]
        fuo = [w for w in Wp if all(w["t"] < g[0] - 1.5 or w["t"] - 0.1 > g[1] + 1.5 for g in G)]
        def r(L, k): return sum(w["hc"].get(k, 0) for w in L) / (len(L) / 10) if L else float("nan")
        print(f"  0x4b dentro i buchi {r(den,0x4b):.0f}/s, fuori {r(fuo,0x4b):.0f}/s; tutta la prova {r(Wp,0x4b):.0f}/s")
        # permutazione circolare dentro la fase
        X = [sovrapp(w["t"] - 0.1, w["t"], G) / 0.1 for w in Wp]; Y = [w["hc"].get(0x4b, 0) for w in Wp]
        if len(X) > 400 and st.pstdev(X) > 0 and st.pstdev(Y) > 0:
            r0 = st.correlation(X, Y); random.seed(1)
            sh = [random.randrange(100, len(X) - 100) for _ in range(1000)]
            rs = sorted(abs(st.correlation(X, Y[k:] + Y[:k])) for k in sh)
            p = (1 + sum(1 for q in rs if q >= abs(r0))) / 1001
            print(f"  permutazione nella fase: r {r0:+.3f}, traslazioni max {rs[-1]:.3f} 95% {rs[950]:.3f}, p {p:.4f}")
        riass[F] = dict(buchi=len(G), somma=sum(gl) / 1000, cicli=len(rf), m4b=r(Wp, 0x4b), d4b=r(den, 0x4b), f4b=r(fuo, 0x4b))
    # memoria di Linux per passo
    mm = []
    for l in open(f"{d}/gapmem-memmon-{F}.txt", errors="replace"):
        if l.startswith("M "):
            a_, b_ = l.split("|"); x = a_.split(); y = b_.split()
            mm.append((a_host(off, int(x[1])), int(x[3]), int(x[4]), int(y[0])))
    MT = [q[0] for q in mm]
    def mem_at(t):
        i = min(max(bisect.bisect_left(MT, t), 0), len(mm) - 1); return mm[i]
    # Windows: working set di vmmem
    wo = win_offset(F); ws = []
    if wo is not None and os.path.exists(f"{d}/memwin{F}.txt"):
        for l in open(f"{d}/memwin{F}.txt", errors="replace"):
            x = l.split()
            if len(x) >= 6 and x[0] == "P" and "WSL" in x[2]: ws.append((int(x[1]) / 1e9 + wo, int(x[4]), int(x[5])))
    WT = [q[0] for q in ws]
    def ws_at(t):
        if not ws: return (0, float("nan"), float("nan"))
        i = min(max(bisect.bisect_left(WT, t), 0), len(ws) - 1); return ws[i]
    print(f"  scarto Windows-host {wo if wo is None else round(wo, 3)} s; campioni vmmem {len(ws)}")
    print(f"  {'passo':<10} {'dMemFree MB':>11} {'dCached MB':>10} {'pgfree MB/s':>11} {'dWS vmmem MB':>12} {'WS fine GB':>10}")
    pm = defaultdict(lambda: defaultdict(list))
    for a, b, c, p in P:
        if c.startswith("R"): p = "R-" + p
        A, Bm = mem_at(a), mem_at(b)
        x = pm[p]; x["mf"].append((Bm[1] - A[1]) / 1024); x["ca"].append((Bm[2] - A[2]) / 1024)
        x["pf"].append((Bm[3] - A[3]) * 4096 / 2**20 / max(b - a, 0.1))
        wa, wb = ws_at(a), ws_at(b); x["ws"].append((wb[1] - wa[1]) / 2**20); x["wsf"].append(wb[1] / 2**30)
    for p in PASSI + ["R-" + q for q in PASSI]:
        x = pm.get(p)
        if not x: continue
        m = lambda k: st.mean(x[k]) if x[k] else float("nan")
        print(f"  {p:<10} {m('mf'):11.0f} {m('ca'):10.0f} {m('pf'):11.1f} {m('ws'):12.0f} {m('wsf'):10.2f}")
    if ws: print(f"  vmmemWSL working set: min {min(q[1] for q in ws)/2**30:.2f} GB, max {max(q[1] for q in ws)/2**30:.2f} GB; privata max {max(q[2] for q in ws)/2**30:.2f} GB")
    # contatori della partizione WSL in Hyper-V
    hp = f"{d}/hvperf{F}.csv"
    if os.path.exists(hp) and wo is not None:
        rr = csv.reader(open(hp, encoding="utf-8", errors="replace", newline="")); h = next(rr)
        want = ["Pagine GPA 4 KB", "Pagine GPA 2 MB", "Pagine frantumate/sec", "Pagine ricombinate/sec",
                "Scaricamenti intero TLB virtuale/sec", "Modifiche spazio GPA/sec", "Pagine depositate"]
        ix = {}
        for i, c in enumerate(h):
            for w_ in want:
                if c.endswith("(Virtual Machine:HvPt)\\" + w_): ix[w_] = i
        rows = []
        for row in rr:
            try: t = datetime.datetime.strptime(row[0], "%m/%d/%Y %H:%M:%S.%f").timestamp() + wo
            except (ValueError, IndexError): continue
            v = {}
            for w_, i in ix.items():
                try: v[w_] = float(row[i])
                except (ValueError, IndexError): pass
            rows.append((t, v))
        for w_ in want:
            xs = [v[w_] for t, v in rows if w_ in v]
            if xs: print(f"  HvPt {w_:<38} min {min(xs):12.0f} max {max(xs):12.0f} media {st.mean(xs):10.1f}")
        # flush TLB di WSL per passo
        fl = defaultdict(list)
        for a, b, c, p in P:
            if c.startswith("R"): continue
            xs = [v.get("Scaricamenti intero TLB virtuale/sec") for t, v in rows if a + 1 <= t <= b and "Scaricamenti intero TLB virtuale/sec" in v]
            if xs: fl[p].append(st.mean(xs))
        print("  flush TLB di WSL per passo: " + ", ".join(f"{p} {st.mean(fl[p]):.0f}/s" for p in PASSI if fl[p]))
    # ragioni delle uscite dell'L1 (solo cicli con exitrsn accesa)
    if EX and rf:
        t0 = rf[0][2]; t1 = (max(g[1] for g in G) + 30) if G else t0 + 480
        Ew = finestre(EX, ET, t0, t1)
        if Ew:
            den = [w for w in Ew if sovrapp(w[0] - 0.1, w[0], G) > 0.05]
            fuo = [w for w in Ew if all(w[0] < g[0] - 1.5 or w[0] - 0.1 > g[1] + 1.5 for g in G)]
            bad = sum(w[1].get(("bad", 0), 0) for w in Ew)
            keys = defaultdict(int)
            for w in Ew:
                for k, n in w[1].items(): keys[k] += n
            print(f"  exitrsn: {len(Ew)} finestre (dentro i buchi {len(den)}, lontane {len(fuo)}), incoerenti {bad}")
            print(f"    {'uscita':<16} {'tutte /s':>9} {'dentro /s':>10} {'fuori /s':>9}")
            for k in sorted(keys, key=lambda k: -keys[k])[:18]:
                if k[0] == "bad": continue
                rt = lambda L: sum(w[1].get(k, 0) for w in L) / (len(L) / 10) if L else float("nan")
                print(f"    {k[0]:<7} {k[1]:>8} {rt(Ew):9.0f} {rt(den):10.0f} {rt(fuo):9.0f}")
    # costo di exitrsn: passi con sonda accesa contro spenta
    for p in PASSI:
        x = per.get(p)
        if not x or not x["on"]: continue
        a1 = [dv for dv, o in zip(x["dur"], x["on"]) if o]; a0 = [dv for dv, o in zip(x["dur"], x["on"]) if not o]
        if a1 and a0: print(f"  costo exitrsn, passo {p}: durata con sonda {st.mean(a1):.1f} s (n {len(a1)}), senza {st.mean(a0):.1f} s (n {len(a0)})")

print("\n################ riassunto")
for F, x in riass.items():
    print(f"  {F}: buchi {x['buchi']} in {x['cicli']} cicli ({x['buchi']/max(x['cicli'],1):.1f}/ciclo, {x['somma']:.1f} s); "
          f"0x4b media {x['m4b']:.0f}/s, dentro {x['d4b']:.0f}/s, fuori {x['f4b']:.0f}/s")
