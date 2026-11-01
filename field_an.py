#!/usr/bin/env python3
# Claude 24/10/2026 -- parere #43 §3: VMREAD/VMWRITE dell'L1 per campo VMCS (fieldrw.d) e
# EPT violation dell'L1 (l1ept.d), dalla corsa run-gap6.sh. Nomi dei campi da vmcs.h.
# Uscita: per fase (C0 = Windows senza WSL, A = prova ext4) la tabella dei campi con letture/s,
# scritture/s e quota cumulata; tempo CPU di vmx_nested_exit per motivo; costo delle sonde
# (passi dei cicli con e senza sonda); EPT violation dell'L1 per regione e pagina.
# uso: field_an.py <cartella della corsa> [vmcs.h]
import re, sys, os, statistics as st
from collections import defaultdict
d = sys.argv[1]
H = sys.argv[2] if len(sys.argv) > 2 else "/mnt/linuxulator2/vm/nested-work/freebsd-nested/sys/amd64/vmm/intel/vmcs.h"
nome = {}
for l in open(H):
    m = re.match(r"#define\s+VMCS_(\w+)\s+(0x[0-9a-fA-F]+)", l)
    if m and m.group(1) not in ("IDENT",): nome.setdefault(int(m.group(2), 16), m.group(1))
def nm(e):
    if e in nome: return nome[e]
    if e & 1 and (e & ~1) in nome and ((e >> 13) & 3) == 1: return nome[e & ~1] + "_HIGH"
    return "?"
TIPO = {0: "controllo", 1: "sola lettura (uscita)", 2: "stato guest", 3: "stato host"}
def tipo(e): return TIPO[(e >> 10) & 3]
LARG = {0: "16", 1: "64", 2: "32", 3: "nat"}

def leggi_field(f):
    """righe S (ogni s) con f motivo campo n; righe T (100 ms) con n motivo conteggio tempo_ns"""
    fr = defaultdict(int); secs = 0; nt = defaultdict(int); tt = defaultdict(int); t0 = t1 = None
    for l in open(f, errors="replace"):
        if l.startswith("S "):
            secs += 1; continue
        if l.startswith("T "):
            t = int(l.split()[1]) / 1e9; t0 = t if t0 is None else t0; t1 = t; continue
        m = re.match(r"\s+f (\d+) (0x[0-9a-f]+) (\d+)", l)
        if m: fr[(int(m.group(1)), int(m.group(2), 16))] += int(m.group(3)); continue
        m = re.match(r"\s+n (\d+) (\d+) (\d+)", l)
        if m: nt[int(m.group(1))] += int(m.group(2)); tt[int(m.group(1))] += int(m.group(3))
    dur = (t1 - t0) if t0 is not None and t1 > t0 else max(secs, 1)
    return fr, nt, tt, dur

gruppi = defaultdict(list)
for f in sorted(os.listdir(d)):
    m = re.match(r"fieldrw-(\w+)-(\w+)\.txt$", f)
    if m: gruppi["C0" if m.group(1) == "C0" else "A"].append(f)
for g, files in gruppi.items():
    FR = defaultdict(int); NT = defaultdict(int); TT = defaultdict(int); DUR = 0
    for f in files:
        fr, nt, tt, dur = leggi_field(f"{d}/{f}")
        for k, v in fr.items(): FR[k] += v
        for k, v in nt.items(): NT[k] += v
        for k, v in tt.items(): TT[k] += v
        DUR += dur
    print(f"\n################ {g}: {len(files)} file, {DUR:.0f} s con fieldrw accesa")
    print("  slow path per motivo (vmx_nested_exit): chiamate/s, us CPU per chiamata (senza uscita/rientro da vmx_run)")
    for r in sorted(NT, key=lambda r: -NT[r])[:12]:
        print(f"    motivo {r:3d}: {NT[r]/DUR:9.0f}/s  {TT[r]/max(NT[r],1)/1000:6.2f} us")
    R = {e: n for (r, e), n in FR.items() if r == 23}; W = {e: n for (r, e), n in FR.items() if r == 25}
    TR, TW = sum(R.values()), sum(W.values())
    print(f"  VMREAD {TR/DUR:.0f}/s su {len(R)} campi; VMWRITE {TW/DUR:.0f}/s su {len(W)} campi")
    tutti = sorted(set(R) | set(W), key=lambda e: -(R.get(e, 0) + W.get(e, 0)))
    print(f"  {'encoding':>8} {'campo':<34} {'larg':>4} {'tipo':<22} {'letture/s':>10} {'scritture/s':>11} {'cum. %':>7}")
    cum = 0; tot = TR + TW
    for e in tutti:
        cum += R.get(e, 0) + W.get(e, 0)
        print(f"  {e:#8x} {nm(e):<34} {LARG[(e>>13)&3]:>4} {tipo(e):<22} {R.get(e,0)/DUR:10.0f} {W.get(e,0)/DUR:11.0f} {100*cum/max(tot,1):7.1f}")

# EPT violation dell'L1
files = [f for f in sorted(os.listdir(d)) if f.startswith("l1ept-")]
if files:
    reg = defaultdict(int); pag = defaultdict(int); mm = defaultdict(int); tot = nuove = rip = 0; secs = 0
    for f in files:
        for l in open(f"{d}/{f}", errors="replace"):
            if l.startswith("S "): secs += 1; continue
            m = re.match(r"\s+tot (\d+) nuove (\d+) ripetute (\d+)", l)
            if m: tot += int(m.group(1)); nuove += int(m.group(2)); rip += int(m.group(3)); continue
            m = re.match(r"\s+reg (0x[0-9a-f]+) acc (\d+) perm (\d+) n (\d+)", l)
            if m: reg[(int(m.group(1), 16), int(m.group(2)), int(m.group(3)))] += int(m.group(4)); continue
            m = re.match(r"\s+pag (0x[0-9a-f]+) n (\d+)", l)
            if m: pag[int(m.group(1), 16)] += int(m.group(2)); continue
            m = re.match(r"\s+mmio (0x[0-9a-f]+) n (\d+)", l)
            if m: mm[int(m.group(1), 16)] += int(m.group(2))
    secs = max(secs, 1)
    print(f"\n################ EPT violation dell'L1: {len(files)} file, {secs} s")
    print(f"  {tot/secs:.0f}/s; pagine 4K nuove {nuove/secs:.0f}/s, gia' viste {rip/secs:.0f}/s")
    acc = lambda a: ("R" if a & 1 else "-") + ("W" if a & 2 else "-") + ("X" if a & 4 else "-")
    print("  regioni da 2 MiB piu' colpite (acc = accesso tentato, perm = permessi EPT presenti):")
    for k in sorted(reg, key=lambda k: -reg[k])[:20]:
        print(f"    {k[0]:#14x} acc {acc(k[1])} perm {acc(k[2])}: {reg[k]/secs:8.1f}/s")
    print("  pagine piu' colpite (somma delle top-20 di ogni secondo):")
    for k in sorted(pag, key=lambda k: -pag[k])[:15]:
        print(f"    {k:#14x}: {pag[k]/secs:8.1f}/s")
    if mm:
        print("  MMIO:")
        for k in sorted(mm, key=lambda k: -mm[k])[:10]: print(f"    {k:#14x}: {mm[k]/secs:8.1f}/s")
