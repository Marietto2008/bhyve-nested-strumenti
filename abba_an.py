#!/usr/bin/env python3
# Claude 24/10/2026 -- parere #47: analisi del benchmark ABBA (run-abba.sh). Per ognuna delle 8
# prove (dati grezzi e delta dei contatori) e per modalita' (media delle 2 repliche):
#  - ext4: cicli, durata media di dd/sha/rilettura, errori sha256, buchi (numero, per ciclo,
#    somma, mediana, massimo);
#  - compilazione: tempo reale ed esito;
#  - per intervallo (Windows fermo, ext4, compilazione): uscite totali/s, percorso lento/s,
#    ingressi in L2/s, EPT02/s, MMIO/s, INVVPID/s, copie shadow/s, VMCLEAR/s, quota L0 (TSC),
#    CPU-secondi dei vCPU e di L0 (assoluti, e per ciclo ext4);
#  - memoria (host e vmmemWSL) all'inizio delle prove;
#  - effetti: S0 (B contro A), shadow (C contro A), combinazione (D contro C e B), interazione
#    D - C - B + A, in percentuale rispetto ad A.
# uso: abba_an.py <cartella abba-...>
import re, sys, os, glob, statistics as st
from collections import defaultdict
TSC = 3600018355
base = sys.argv[1]

def leggi_foto(path):
    foto = {}; cur = None
    for l in open(path, errors="replace"):
        m = re.match(r"FOTO (\S+) ([\d.]+)", l)
        if m: cur = m.group(1); foto[cur] = {"t": float(m.group(2)), "s": defaultdict(int), "cpu": 0.0}; continue
        if cur is None: continue
        m = re.match(r"hw\.vmm\.vmx\.(\S+): (\d+)$", l.strip())
        if m: foto[cur]["s"]["x:" + m.group(1)] = int(m.group(2)); continue
        m = re.match(r"\s*\d+\s+(\d+):([\d.]+)\s+bhyve/vcpu (\d+)", l)
        if m: foto[cur]["cpu"] += int(m.group(1)) * 60 + float(m.group(2)); continue
        m = re.match(r"(.*\S)\s+(\d+)$", l.rstrip("\n"))
        if m and not re.match(r"vcpu\d+ stats", l): foto[cur]["s"][m.group(1).strip()] += int(m.group(2))
    return foto

K = [("total number of vm exits", "uscite"), ("exit nested gestite nello slow path", "lento"),
     ("ingressi in L2", "ingL2"), ("x:vst_fault", "EPT02"), ("vm exits for instruction emulation", "MMIO"),
     ("Number of vpid invalidations done", "INVVPID"), ("x:nested_sh_push", "copie"),
     ("x:nested_sh_clear", "VMCLEAR"), ("x:nested_sh_faults", "ERRsh")]

def intervallo(F, a, b):
    if a not in F or b not in F: return None
    A, B = F[a], F[b]; dt = B["t"] - A["t"]; cpu = B["cpu"] - A["cpu"]
    r = {n: (B["s"][k] - A["s"][k]) / dt for k, n in K}
    g = (B["s"]["x:nested_l1_tsc"] + B["s"]["x:nested_l2_tsc"] - A["s"]["x:nested_l1_tsc"] - A["s"]["x:nested_l2_tsc"]) / TSC
    r["L0%"] = 100 * (1 - g / cpu) if cpu > 0 else float("nan")
    r["cpu_s"] = cpu; r["L0_s"] = cpu - g; r["dt"] = dt
    vf = sum(B["s"][k] - A["s"][k] for k in ("VMfailValid restituiti all'L1", "VMfailInvalid restituiti all'L1"))
    r["VMfail"] = vf
    return r

def ext4(d):
    out = {}
    try:
        ev = [(m.group(1), m.group(2), float(m.group(3))) for m in
              (re.match(r"CICLO (\S+) (\S+) ([\d.]+)", l) for l in open(d + "/gapmem-A.log")) if m]
        G = [int(m.group(1)) for m in (re.match(r"BUCO (\d+) ms", l) for l in open(d + "/gapmem-gapmon-A.txt")) if m]
    except FileNotFoundError:
        return out
    du = defaultdict(list)
    for i in range(len(ev) - 1):
        c, p, t = ev[i]
        if c.startswith("R") or ev[i + 1][0] != c: continue
        du[p].append(ev[i + 1][2] - t)
    out["cicli"] = sum(1 for c, p, t in ev if p == "ok" and not c.startswith("R"))
    out["errori_sha"] = sum(1 for c, p, t in ev if p == "ERRORE")
    for p in ("dd", "sha", "rilettura"):
        out[p] = st.mean(du[p]) if du[p] else float("nan")
    out["buchi"] = len(G); out["buchi_s"] = sum(G) / 1000
    out["buchi_med"] = st.median(G) if G else 0; out["buchi_max"] = max(G) if G else 0
    out["buchi_ciclo"] = len(G) / out["cicli"] if out["cicli"] else float("nan")
    return out

def compil(d):
    try:
        t = open(d + "/kbuild.log", errors="replace").read()
    except FileNotFoundError:
        return float("nan"), "?"
    m = re.search(r"^real\s+(\d+)m([\d.]+)s", t, re.M); rc = re.search(r"kernel rc=(\d+)", t)
    return (int(m.group(1)) * 60 + float(m.group(2)) if m else float("nan")), (rc.group(1) if rc else "?")

prove = []
for d in sorted(glob.glob(base + "/*-[ABCD]"), key=lambda x: int(os.path.basename(x).split("-")[0])):
    n, mod = os.path.basename(d).split("-")
    if not os.path.exists(d + "/foto.txt"): continue
    F = leggi_foto(d + "/foto.txt")
    p = {"n": int(n), "mod": mod, "d": d,
         "fermo": intervallo(F, "02-inizio", "02-fine"),
         "ext4": intervallo(F, "04-prova-inizio", "04-fine"),
         "comp": intervallo(F, "05-inizio", "05-fine"),
         "tutto": intervallo(F, "00-prima", "06-fine")}
    p.update(ext4(d)); p["comp_s"], p["comp_rc"] = compil(d)
    if p["ext4"] and p.get("cicli"):
        p["L0_s_ciclo"] = p["ext4"]["L0_s"] / p["cicli"]; p["cpu_s_ciclo"] = p["ext4"]["cpu_s"] / p["cicli"]
    try:
        mem = open(d + "/memoria.txt", errors="replace").read()
        m = re.search(r"== 04-prima-ext4.*?\n(\d+) (\d+) (\d+) (\d+)", mem, re.S)
        p["host_libera_GB"] = int(m.group(1)) * int(m.group(4)) / 2**30 if m else float("nan")
        m = re.search(r"== 04-prima-ext4.*?vmmemWSL\s+(\d+)\s+(\d+)", mem, re.S)
        p["vmmem_GB"] = int(m.group(1)) / 2**30 if m else float("nan")
    except FileNotFoundError:
        pass
    prove.append(p)

def g(p, *k):
    v = p
    for x in k:
        if v is None: return float("nan")
        v = v.get(x, float("nan")) if isinstance(v, dict) else float("nan")
    return v

righe = [("ext4: cicli", ("cicli",)), ("ext4: dd s", ("dd",)), ("ext4: sha s", ("sha",)), ("ext4: rilettura s", ("rilettura",)),
         ("ext4: errori sha256", ("errori_sha",)), ("ext4: buchi", ("buchi",)), ("ext4: buchi/ciclo", ("buchi_ciclo",)),
         ("ext4: buchi somma s", ("buchi_s",)), ("ext4: buchi mediana ms", ("buchi_med",)), ("ext4: buchi max ms", ("buchi_max",)),
         ("compilazione s", ("comp_s",)),
         ("ext4: uscite/s", ("ext4", "uscite")), ("ext4: percorso lento/s", ("ext4", "lento")), ("ext4: ingressi L2/s", ("ext4", "ingL2")),
         ("ext4: EPT02/s", ("ext4", "EPT02")), ("ext4: MMIO/s", ("ext4", "MMIO")), ("ext4: INVVPID/s", ("ext4", "INVVPID")),
         ("ext4: copie shadow/s", ("ext4", "copie")), ("ext4: VMCLEAR shadow/s", ("ext4", "VMCLEAR")),
         ("ext4: quota L0 %", ("ext4", "L0%")), ("ext4: CPU vCPU s", ("ext4", "cpu_s")), ("ext4: CPU L0 s", ("ext4", "L0_s")),
         ("ext4: CPU vCPU s/ciclo", ("cpu_s_ciclo",)), ("ext4: CPU L0 s/ciclo", ("L0_s_ciclo",)),
         ("fermo: uscite/s", ("fermo", "uscite")), ("fermo: quota L0 %", ("fermo", "L0%")),
         ("comp: uscite/s", ("comp", "uscite")), ("comp: quota L0 %", ("comp", "L0%")), ("comp: CPU L0 s", ("comp", "L0_s")),
         ("VMfail (tutta la prova)", ("tutto", "VMfail")), ("errori shadow (tutta)", ("tutto", "ERRsh")),
         ("host libera GB (prima ext4)", ("host_libera_GB",)), ("vmmemWSL WS GB (prima ext4)", ("vmmem_GB",))]
print("######## dati grezzi per prova")
print(f"{'':30}" + "".join(f"{str(p['n'])+'-'+p['mod']:>11}" for p in prove))
for nome, k in righe:
    print(f"{nome:30}" + "".join(f"{g(p, *k):11.2f}" for p in prove))
print("\n######## medie per modalita' (2 repliche) ed effetti in % rispetto ad A")
med = {}
for m in "ABCD":
    ps = [p for p in prove if p["mod"] == m]
    med[m] = {nome: (st.mean([g(p, *k) for p in ps]) if ps else float("nan")) for nome, k in righe}
    med[m]["_n"] = len(ps)
print(f"{'':30}" + "".join(f"{m+' (n'+str(med[m]['_n'])+')':>11}" for m in "ABCD") + f"{'S0 %':>9}{'shadow %':>9}{'D %':>9}{'interaz.':>9}")
for nome, k in righe:
    a, b, c, dd = (med[m][nome] for m in "ABCD")
    pct = lambda x: 100 * (x - a) / a if a not in (0, float("nan")) and a == a and a != 0 else float("nan")
    inter = dd - c - b + a
    print(f"{nome:30}" + "".join(f"{med[m][nome]:11.2f}" for m in "ABCD") + f"{pct(b):9.1f}{pct(c):9.1f}{pct(dd):9.1f}{inter:9.2f}")
