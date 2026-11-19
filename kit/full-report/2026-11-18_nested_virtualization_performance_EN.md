# Nested virtualization performance on bhyve — 18 Nov 2026

*English translation of `2026-11-18_prestazioni_virtualizzazione_annidata.md`. File names, script names and
measurement labels quoted from data files are left in Italian, as they appear on disk.*

Host: Intel i9-9900K (8 cores, 16 threads, 3.6 GHz), 64 GB, FreeBSD 16.0-CURRENT. Modules and versions:
- vmm module `vmm-restore.ko` `96d52f3d…` (branch `vmm-nested-16-lavoro`, 2c665a22bfc7);
- bhyve from the series `d393103a…`;
- QEMU `qemu-sipi` `952a4086…` with `-accel bhyve,nested=on`.

Written by Claude at the user's request: "write a report with each test performed and the value obtained. The more
permutations you cover, the better."

The document has four parts:
- **I**, the summary;
- **II**, the measurements extracted from the project's history (20 Oct – 17 Nov);
- **III**, the new measurements of 18 Nov, with the same benchmark at every level;
- **IV**, method, tools, conditions, and the mistakes made during the campaign.

---

## Part I — Summary

**Permutations measured on 18 Nov** (the same `claude-banco` binary everywhere, except Windows, which uses `winsat`):

| level | system | hypervisor underneath | runs |
|---|---|---|---:|
| L0 | FreeBSD 16 (host), idle and with Windows running | — | 1 + 1 |
| L1 | FreeBSD 15.1 | bhyve, without and with VMX exposed | 1 + 1 |
| L1 | Ubuntu 24.04 (Linux 6.17) | bhyve, VMX exposed | 1 |
| L1 | Windows 11 | QEMU+bhyve with Hyper-V on / off; native bhyve with Hyper-V | winsat ×3 |
| L2 | FreeBSD 15.1 | **bhyve** inside L1 FreeBSD inside bhyve | 2 |
| L2 | FreeBSD 15.1 (same image) | **KVM** inside L1 Ubuntu inside bhyve | 2 |
| L2 | FreeBSD 15.2 (ro7d) | **Hyper-V / WSL2** inside Windows inside QEMU+bhyve | 3 |
| L2 | FreeBSD 15.2 (ro7d) | **Hyper-V / WSL2** inside Windows inside native bhyve | 2 |
| L2 | Debian 13.5 (WSL Linux kernel) | **Hyper-V / WSL2** inside Windows inside QEMU+bhyve | 2 |

**What the numbers say.**

1. **A single level (L1) under bhyve costs almost nothing.**
   - **Native:** CPU, `fork`, cross-CPU pipe and `memcpy` run as fast as on the host (×1.0), for both FreeBSD and Ubuntu.
   - **Only fixed cost:** a system call costs about 3× more (144–168 ns vs 47 ns). Part of that comes from the guest itself: 15.1-RELEASE vs 16-CURRENT, and PTI enabled in the guest.
   - **Exposing VMX to the L1 costs nothing:** the "without / with VMX" columns are identical within noise.
2. **Nesting is expensive, and the cost depends mostly on the L1 hypervisor**, not on the bhyve underneath:

   | times slower than the host | bhyve in bhyve | KVM in bhyve | Hyper-V in bhyve |
   |---|---:|---:|---:|
   | pure CPU, 1 thread | 1.2 | 1.1 | 1.5–1.6 |
   | `fork` + `exec` | 8.5 | 5.4 | 9–14 |
   | pipe between 2 CPUs (IPI wake-up) | 421 | 273 | 194–492 |
   | first write to pages | **71** | 4.1 | 16–28 |
   | `memcpy` | 1.3 | 1.2 | **7–14** |

   - **KVM as the L1** is the best on almost everything.
   - **bhyve as the L1** has one clear weak spot: the first write to pages, that is, EPT violations resolved through two levels.
   - **Hyper-V as the L1** has its own weak spots:
     - memory bandwidth collapses, to ~1 GB/s against ~10 GB/s in every other case;
     - pure CPU loses 30–40%.

     Both come from the WSL VM, not from bhyve: on the same bhyve chain underneath, KVM keeps `memcpy` at 9.6 GB/s.
3. **Waking another CPU is the biggest cost in every L2**: a pipe round trip goes from 3.8 µs to 0.7–1.9 ms. Every
   IPI from the L2 crosses three levels, and the 9900K has neither APICv nor posted interrupts.
   - **At L1:** the same effect, smaller, already shows with Linux. In Ubuntu the pipe takes 85 µs, because an idle Linux puts CPUs in HLT and each wake-up exits to bhyve; FreeBSD stays at 3.9 µs.
4. **Timers**: in the L2 a 1 ms sleep lasts 1.3–2 ms at the median (476–1024 µs of extra delay). Under Hyper-V the maximum reaches 60–320 ms. The 429.5 s gap seen on 15 Nov disappeared after the TSC fix (Part II.5).
5. **L0 front-end for Windows: native bhyve and QEMU+bhyve are equivalent.**
   - **Windows (L1):** CPU and memory are the same within 5%.
   - **WSL L2:** gives the same numbers under either one.
6. **Hyper-V on or off does not change Windows' CPU at L1** (`winsat`: single-thread compression 99.6 / 99.3 MB/s).
   - **Memory without Hyper-V:** `winsat mem` does not run, failing with "cannot measure the TSC (Time Stamp Counter) frequency". With Hyper-V on, the frequency comes from the hypervisor; without it, Windows must work it out by itself. The most likely explanation is that our L0 does not provide CPUID leaves 0x15/0x16 with the TSC frequency: this is a hypothesis, **not yet verified**.
7. **Nested network and disk are slow.**
   - **Network to the host:** 5–35 MB/s in the L2s, against 107–423 MB/s in the L1s and over 1.6 GB/s locally on the host.
   - **Disk** (1 GB written with `fsync`, on the same USB G-DRIVE): 211 MB/s from the host, 68–152 MB/s from L1 and L2. Under bhyve-in-bhyve it drops to 30–43 MB/s.
8. **From the history** (Part II): building the Linux kernel in the WSL2 L2 went from 85:41 (20 Oct, 2 VPs) to 10:38 (27 Oct, 8 VPs). That is a factor of 8: about 2× from selective INVEPT and B1, about 1.3× from the shadow VMCS, the rest from more VPs. Windows boots in 130 s at the median (100 boots).

**Where work would pay off most**, in order of expected gain:
1. **cross-CPU wake-up in the L2**, i.e. delivery of nested IPIs;
2. **EPT violations when the L1 is bhyve**, the bhyve-in-bhyve case;
3. **the memory path of the WSL VM**: Hyper-V's INVEPTs and the removed pages, as measured with FRAME on 17 Nov.

---

## Part II — Measurements from the project's history (20 Oct – 17 Nov 2026)

All on this host (i9-9900K, 8 cores / 16 threads, 64 GB, FreeBSD 16-CURRENT as L0). Each row states the
configuration and the source. Values from different periods are **not** always comparable: the vmm module, the
vCPUs, the host load (in some series swap was at 100%) and the state of Windows all changed.

### II.1 Building Linux kernel 6.6.58 (`defconfig`) in WSL2 (Linux L2), Windows 11 + Hyper-V (L1), bhyve (L0)

| date | configuration (module / new feature) | VPs | `make` | time | source |
|---|---|---:|---|---:|---|
| 20 Oct | phase A: L1 INVEPT = flush of ALL roots | 2 | -j2 | **85:41** | Per-Astra 2026-10-21 faseA |
| 21 Oct | A: before selective INVEPT (2 runs) | 2 | -j2 | 43:51 / 52:17 (mean 48:04) | 2026-10-21 shadow_ept_oltre_invept |
| 21 Oct | B: selective single-context INVEPT (3 runs) | 2 | -j2 | 42:27 / 43:51 / 40:31 (mean **42:16**, −12%) | same |
| 21 Oct | phase C: B1 (EPT02 roots kept) | 2 | -j2 | 39:14 | 2026-10-21 faseC |
| 23 Oct | B1, 2-VP series | 2 | -j2 | 21:51 / 23:06 / 26:03 | 2026-10-23 faseB |
| 23 Oct | B1, "4 vCPUs" (actually 2 active VPs) | 2 | -j2 / -j4 | 23:25 / 26:47 | 2026-10-23 faseB |
| 23 Oct | B1, 4 real VPs (1 socket × 4 cores) | 4 | -j2 / -j4 | 27:51 / **17:49** | 2026-10-23 4vcpu_veri |
| 23 Oct | page-walk retry 2, 4 VPs | 4 | -j4 | 16:31 / 16:01 / **15:13** / 17:35 | 2026-10-23 retry2_4vp |
| 24 Oct | shadow VMCS + verification | 2 | -j4 | 24:04 | 2026-10-24 fase06 |
| 25 Oct | ABBA shadow VMCS: baseline A (4 runs) | 2 | -j4 | 1622 / 1837 / 1822 / 1380 s | 2026-10-25 ABBA_shadow_S0, ABBA_bis |
| 25 Oct | ABBA shadow VMCS: shadow C (4 runs) | 2 | -j4 | 1264 / 1316 / 1250 / 1261 s (**−22/−28%**) | same |
| 25 Oct | ABBA VPID: tracking off (A) / on (B) | 2 | -j4 | mean 1221.5 / **1186.0 s** (−2.9%) | 2026-10-25 ABBA_VPID_benchmark |
| 25 Oct | VPID tracking, full Windows session | 2 | -j4 | 30:42 | 2026-10-25 Windows_VPID_tracking |
| 27 Oct | ABBA retry 1 / retry 2, 2 VPs | 2 | -j4 | 1326 / 1317 / 1225 / 1290 s | 2026-10-27 ABBA_2VP |
| 27 Oct | 8 VPs, arm A / B | 8 | -j8 | 691 / **638 s** (10:38) | 2026-10-27 8VP_braccio_B |
| 27 Oct | 8 VPs, arm D (budget 4000) | 8 | -j8 | 675 s (+5.7%) | 2026-10-27 8VP_braccio_D |

Reading: from the first working version (85:41 at 2 VPs) to the best 8-VP arm (10:38), the time drops
**8-fold**. About 2× comes from selective INVEPT and B1, ~1.3× from the shadow VMCS, the rest from more VPs.

### II.2 WSL2 ext4 test (480 s of write / sha256 / re-read cycles on ext4) and L0 cost

| series | baseline (A) | shadow VMCS (C) | effect |
|---|---:|---:|---|
| ext4 cycles in 480 s (ABBA 25 Oct, 4+4 runs) | 13 / 13 / 13 / 15 | 19 / 19 / 18 / 18 | **+29…+46%** |
| L0 CPU per ext4 cycle | 32.8–34.5 s | 14.6–18.5 s | **−40…−51%** |
| exits/s during the ext4 test | 226–234 k | 115–135 k | −45% |
| dd / sha / re-read of one cycle (s) | 13.3 / 6.8 / 12.7 | 9.9 / 4.5 / 8.6 | −25…−35% |
| share of vCPU time spent in L0 (TSC), Windows idle | 43.6–66.7% | 20.1–29.6% | |
| share in L0, kernel build | 45–47% | 26–33% | |
| copy to / back from the shadow VMCS | — | 1.35–2.12 / 0.76–1.22 µs | 1.6–3.5% of vCPU time |

Sources: 2026-10-24 fase06, 2026-10-25 ABBA_shadow_S0 and ABBA_bis_swap_vuoto. S0 (fewer VMREADs in the slow
path) has no measurable effect (−1.9% / +7%, within noise).

### II.3 Exits and elementary nesting costs (bhyve L0)

| quantity | value | conditions / source |
|---|---:|---|
| EPT violations during the build, before / after selective INVEPT | 149,463 / **83,684**/s | 21 Oct, −44% |
| EPT violations per L1 INVEPT, before / after | ~7,600 / ~1,580 | same |
| L2 exits for EPT violation in 237 min (phase A) | 2.17 billion (40× everything else) | 20 Oct |
| L1 / L2 exits per second (WSL active) | 216 k / 42 k | 24 Oct, memory note bhyve_simile_a_kvm |
| L0 share of L1 exits | 37–45% of vCPU time | same |
| VMREAD emulated in the slow path | 1.8 µs | 24 Oct gap6 |
| mean duration of one E0→CR3 emulation (bhyve) | 44 µs | 11 Nov, amp030 baseline |
| mean duration of the same emulation under KVM | 10.6 µs (4–16 µs) | 11 Nov, dati-kvm durata3 |
| L1 INVEPTs per build, 2 VPs / 4 VPs / 8 VPs | ~48 k / 185–239 k / 357–394 k | 23 Oct, 27 Oct |
| INVEPT handler: mean duration, retry 1 / retry 2 | ~435 / ~566 µs | 23 Oct |
| handler CPU, 8 VPs | 8.3–8.4% of vCPU time | 27 Oct |
| false VPID01 migration removed (tracking): INVVPID01 per build | 34.8 M → 44 | 25 Oct |

### II.4 Boot

| what | value | conditions / source |
|---|---:|---|
| Windows 11 boot (Diagnostics-Performance 100, measured by Windows), 100 boots 2–17 Nov | median **130 s**, p10 113 s, p90 152 s, min 76 s, max 234 s | QEMU+bhyve, Hyper-V on, 8 vCPUs; avvii-windows-storia-20261117 |
| Windows desktop (23 Oct series) | 63–92 s (6/6) at 4 vCPUs; 99–113 s (7/7) | 2026-10-23 |
| Windows desktop (20 Oct series) | 107–122 s | memory note nested_vmx_vmcs12 |
| Windows to SSH, nesting on, no GPU | 59–70 s | 4 Nov, 24 Oct |
| in-place reset (R2), to desktop | 155–238 s; cold 90–100 s | 15 Nov |
| FreeBSD L2 under QEMU-WHPX inside Windows, until the storm starts | ~115 s; 313 s with shadow VMCS on | 13 Nov |
| L2 FreeBSD 15.1 under KVM inside L1 Ubuntu (bhyve), to login | 245 s | 7 Nov |
| FreeBSD guest with a passed-through Radeon GPU (no nesting), to login | 8 s | memory note passthrough_gpu |

### II.5 Timer latency in the WSL2 FreeBSD L2 (`claude-lag`: 8 threads × 2 ms sleep, 1200 s)

| L0 | condition | gaps ≥ 100 ms | worst | source |
|---|---|---:|---:|---|
| **KVM** (Linux 6.8) | storm without trimming | 0 | < 100 ms | dati-kvm 9 Nov |
| KVM | with vmmemWSL trimmed every second | 37–48 | 157–201 ms | dati-kvm 9–10 Nov |
| bhyve | as above, amplifier off, Hyper-V-TSC timecounter, before the TSC fix | up to 1214, 6 of them **429.5 s** | 429.6 s | 15 Nov, run 3 |
| bhyve | after the TSC fix (c54958ec), with the 1000 µs amplifier | 6,826–9,049 | 1.5–9.4 s, **none of 429 s** | 16 Nov |

From 11 Nov onwards, almost all storms under bhyve are **amplified** (1000 µs added to every episode, to
provoke the panic): their gaps are not comparable with KVM. The clean comparison, without amplifier, is in
Part III (the `timer` test of claude-banco).

### II.6 Network, disk, GPU

| what | value | source |
|---|---:|---|
| disk in Windows with nesting + GPU (before the fix) | ~7,000 preadv/s, then collapse | 4 Nov, opinion 005 |
| `stress-ng cpu` / `vm` in WSL2 before / after "immediate exit" | 317.8 / 903.2 bogo-ops/s (×2.8); 332.8 / 3320.6 (×10) | 21 Oct |
| maximum delay of L1 interrupt re-injection, before / after | up to 4 s / 0.86 s | 21 Oct |
| Windows root-partition sampler (expected every 10 ms) | 1 sample every 54 ms, gaps up to 12 s | 20 Oct, phase A |

---

## Part III — Measurements of 18 Nov 2026 (claude-banco at every level)

Tables generated by `strumenti/banco-tabella.py` (sha `539c7d78…`) from the files in `dati-banco/`: no number is
copied by hand. Mean of the runs; the range is in parentheses when the spread exceeds 5%.
⁽¹²⁰ˢ⁾ = transfer stopped by the 120 s cap before 1 GB (the rate is bytes/time and is valid); ⁽ⁿᶜ⁾ = L1 FreeBSD
download re-measured with `nc -d` (in the benchmark run it was only a lower bound, see Part IV).

### III.1 Absolute values

| test | unit | L0 host idle | L0 host, Windows running | L1 FreeBSD / bhyve | L1 FreeBSD / bhyve, VMX exposed | L1 Ubuntu / bhyve | L2 FreeBSD / bhyve / bhyve | L2 FreeBSD / KVM (Ubuntu) / bhyve | L2 FreeBSD / Hyper-V (WSL2) / QEMU+bhyve | L2 FreeBSD / Hyper-V (WSL2) / bhyve | L2 Debian / Hyper-V (WSL2) / QEMU+bhyve |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| runs | | 1 | 1 | 1 | 1 | 1 | 2 | 2 | 3 | 2 | 2 |
| CPU, 1 thread | Msteps/s | 467 | 469 | 465 | 464 | 444 | 403 | 410 | 284 (264–324) | 320 | 345 |
| CPU, all threads (per thread) | Msteps/s | 451 | 408 | 465 | 464 | 442 | 379 | 398 | 233 (214–254) | 238 (229–246) | 269 (244–294) |
| system call (getppid) | ns | 47.3 | 47.5 | 144 | 144 | 168 | 172 | 165 | 289 (226–395) | 209 | 242 (232–252) |
| fork + exec + wait | µs | 554 | 590 | 559 | 560 | 572 | 4695 | 2987 | 6943 (5732–9281) | 4851 | 7874 (7367–8381) |
| pipe between 2 CPUs, round trip (median) | µs | 3.80 | 3.80 | 3.90 | 3.90 | 85.4 | 1601 | 1037 | 1869 (1784–1913) | 1798 | 738 |
| pipe, p99 | µs | 5.20 | 6.20 | 6.50 | 6.90 | 131 | 2261 | 1336 | 4420 (3708–5704) | 3542 | 1608 (1480–1736) |
| 1 ms sleep: median extra delay | µs | 2.00 | 2.00 | 34.0 | 32.0 | 107 | 844 | 476 | 970 (878–1019) | 1024 (939–1110) | 395 (325–465) |
| 1 ms sleep: p99 extra delay | µs | 334 | 439 | 49.0 | 47.0 | 148 | 1634 (1541–1728) | 780 | 7594 (7364–8028) | 5776 (4335–7218) | 2742 (2210–3274) |
| 1 ms sleep: maximum extra delay | µs | 73053 | 34800 | 572 | 367 | 1476 | 18838 (2487–35188) | 16398 (6478–26317) | 158414 | 62678 (58876–66480) | 254978 (189845–320112) |
| first write to 4 KB pages | k/s | 743 | 718 | 1147 | 1137 | 905 | 10.5 (9.60–11.4) | 183 (165–201) | 26.4 (24.8–27.9) | 30.6 | 45.3 |
| memcpy 256 MB, 1 thread | GB/s | 11.5 | 10.4 | 11.8 | 11.2 | 16.6 | 8.99 (8.75–9.23) | 9.62 | 1.65 (1.22–2.06) | 0.82 (0.74–0.90) | 0.92 |
| disk: 1 GB written + fsync | MB/s | 211 | 211 | 68.3 | 70.7 | 120 | 36.5 (29.7–43.4) | 377 (93.8–660) | 81.3 (67.0–101) | 92.4 (71.7–113) | 152 |
| network: host → guest | MB/s | 1680 | 1609 | 107 ⁽ⁿᶜ⁾ | 107 ⁽ⁿᶜ⁾ | 423 | 8.25 ⁽¹²⁰ˢ⁾ | 14.4 (14.0–14.8) | 5.16 (4.72–5.74) ⁽¹²⁰ˢ⁾ | 6.37 ⁽¹²⁰ˢ⁾ | 21.1 (17.9–24.3) |
| network: guest → host | MB/s | 2120 | 2024 | 99.0 | 81.0 | 264 | 9.38 (9.13–9.63) | 35.7 (32.1–39.3) | 15.6 (14.1–17.3) | 22.4 (21.6–23.2) | 33.8 (28.0–39.5) |

Files behind each column:

- L0 host idle: banco-L0-riposo-20261118-143542.txt
- L0 host, Windows running: banco-L0-winaccesa-20261118-122156.txt
- L1 FreeBSD / bhyve: banco-L1-fbsd-bhyve-senza-nesting-20261118-154002.txt
- L1 FreeBSD / bhyve, VMX exposed: banco-L1-fbsd-bhyve-con-nesting-20261118-154631.txt
- L1 Ubuntu / bhyve: banco-L1-ubuntu-bhyve-20261118-155433.txt
- L2 FreeBSD / bhyve / bhyve: banco-L2-fbsd-bhyve-in-bhyve-20261118-171511-r1.txt, banco-L2-fbsd-bhyve-in-bhyve-20261118-172105-r2.txt
- L2 FreeBSD / KVM (Ubuntu) / bhyve: banco-L2-fbsd-kvm-in-ubuntu-20261118-155832.txt, banco-L2-fbsd-kvm-in-ubuntu-20261118-160145-r2.txt
- L2 FreeBSD / Hyper-V (WSL2) / QEMU+bhyve: banco-L2-wsl-fbsd-20261118-132746.txt, banco-L2-wsl-fbsd-20261118-135345-r2.txt, banco-L2-wsl-fbsd-20261118-140020-r3.txt
- L2 FreeBSD / Hyper-V (WSL2) / bhyve: banco-L2-wsl-fbsd-L0bhyve-20261118-151726-r1.txt, banco-L2-wsl-fbsd-L0bhyve-20261118-152254-r2.txt
- L2 Debian / Hyper-V (WSL2) / QEMU+bhyve: banco-L2-wsl-debian-20261118-142651.txt, banco-L2-wsl-debian-20261118-143047-r2.txt

### III.2 Slowdown relative to the idle host

| times slower than idle L0 | L1 FreeBSD / bhyve | L1 FreeBSD / bhyve, VMX exposed | L1 Ubuntu / bhyve | L2 FreeBSD / bhyve / bhyve | L2 FreeBSD / KVM (Ubuntu) / bhyve | L2 FreeBSD / Hyper-V (WSL2) / QEMU+bhyve | L2 FreeBSD / Hyper-V (WSL2) / bhyve | L2 Debian / Hyper-V (WSL2) / QEMU+bhyve |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| CPU, 1 thread | 1.0 | 1.0 | 1.1 | 1.2 | 1.1 | 1.6 | 1.5 | 1.4 |
| CPU, all threads (per thread) | 1.0 | 1.0 | 1.0 | 1.2 | 1.1 | 1.9 | 1.9 | 1.7 |
| system call (getppid) | 3.0 | 3.0 | 3.6 | 3.6 | 3.5 | 6.1 | 4.4 | 5.1 |
| fork + exec + wait | 1.0 | 1.0 | 1.0 | 8.5 | 5.4 | 12.5 | 8.8 | 14.2 |
| pipe between 2 CPUs, round trip (median) | 1.0 | 1.0 | 22 | 421 | 273 | 492 | 473 | 194 |
| first write to 4 KB pages | 0.6 | 0.7 | 0.8 | 71 | 4.1 | 28 | 24 | 16.4 |
| memcpy 256 MB, 1 thread | 1.0 | 1.0 | 0.7 | 1.3 | 1.2 | 7.0 | 14.0 | 12.6 |

Reading the columns:
- **L1 FreeBSD / bhyve**: native. The first write to pages is even faster than on the host (1,147 vs 743 k/s), but the two kernels differ: the host runs 16-CURRENT, the guest 15.1-RELEASE.
- **L1 Ubuntu**: native, except pipe (85 µs) and timer (107 µs). On Linux, waking an idle CPU goes through HLT.
- **L2 bhyve-in-bhyve vs KVM-in-bhyve.** The image is *the same* (FreeBSD 15.1, converted from qcow2 to raw), and so are the vCPUs (8) and the memory (8 GB). Only the L1 hypervisor changes, and bhyve loses mostly on pages (10.5 vs 183 k/s), on `fork` (4.7 vs 3.0 ms) and on the pipe (1.6 vs 1.0 ms).
- **L2 Hyper-V**: memory collapses, with `memcpy` at 0.8–1.7 GB/s, and CPU loses 30–40%. Debian and FreeBSD behave similarly under Hyper-V; Debian has better pipe and timer figures.

### III.3 Windows 11 as L1 (`winsat`, 8 vCPUs, 32 GB)

| test | QEMU+bhyve, Hyper-V on | QEMU+bhyve, Hyper-V off | native bhyve, Hyper-V on |
|---|---:|---:|---:|
| CPU compression, 1 thread (MB/s) | 99.6 | 99.3 | 104.5 |
| CPU compression, all threads (MB/s) | 793.5 | 790.5 | 798.6 |
| CPU AES encryption, 1 thread (MB/s) | 993.6 | 975.8 | 996.3 |
| CPU AES encryption, all threads (MB/s) | 7,936.6 | 7,779.4 | 7,943.3 |
| memory bandwidth (MB/s) | 37,527 | not measurable (TSC) | 40,159 |
| disk, sequential read (MB/s) | 206.9 | 232.1 | 178.9 |
| disk, sequential write (MB/s) | 5,131 ⁽ᶜ⁾ | 214.3 | 200.5 |
| disk, random read (MB/s) | 1.24 | 0.87 | 0.56 |

⁽ᶜ⁾ That value is QEMU's cache, not the disk (the test took 287 s instead of the usual 10–15). Files:
`banco-L1-windows-winsat-20261118-1420.txt`, `…senza-hyperv-winsat-20261118-1502-r2.txt`,
`…bhyve-hyperv-winsat-20261118-1517.txt`, `…senza-hyperv-winsat-mem.txt` (the TSC error).

### III.4 Boot times measured along the way

| what | time |
|---|---:|
| Windows 11 under QEMU+bhyve, Hyper-V off: from QEMU start to SSH | < 4 min (boot at 14:38:53) |
| L2 FreeBSD 15.1 under KVM in Ubuntu: from `systemd-run` to SSH | ~60 s (on 7 Nov, with the module of that time: 245 s) |
| L2 FreeBSD 15.1 under bhyve in L1 FreeBSD: from bhyve to SSH | ~80 s (17 s of waiting after the first check) |
| L1 FreeBSD 15.1 under bhyve: from bhyve to the serial prompt | ~30 s |

---

## Part IV — Method, tools, conditions, mistakes

**Tools** (in `confronto-kvm-bhyve/strumenti/`, 16-digit sha):

| file | sha | what it does |
|---|---|---|
| `claude-banco.c` | `1a25257d4efa6624` | the tests, 5 s each; static on FreeBSD, compiled on the spot on Linux |
| `claude-banco` | `67baed1d82778f9d` | the binary used in every FreeBSD run (L0, L1, L2) |
| `banco-livello.sh` | `6af906373abf8d73` | benchmark + 1 GB with `fsync` + network to the host (`nc` or `/dev/tcp`) |
| `banco-wsl.sh` / `banco-wsl.ps1` | `3c76b2c7492a6c27` / `234ef0fd9717d5ac` | runs inside WSL through a scheduled task (approved by the user on 18 Nov) |
| `winps.sh` | `eab7404450f7eb8c` | PowerShell in Windows via `-EncodedCommand` (approved) |
| `banco-tabella.py` | `539c7d781b9983b2` | builds the Part III tables from the files |

**The `claude-banco` tests.**
- **cpu1 / cpuN:** pure integer computation (multiplications and shifts); never exits the VM.
- **syscall:** `getppid()`.
- **fork:** `fork` + `execve(/usr/bin/true)` + `wait`.
- **pipe:** 20,000 one-byte round trips between two threads pinned to different CPUs (0 and N/2).
- **timer:** `nanosleep(1 ms)` on one thread per CPU, recording the delay beyond the millisecond.
- **pages:** `mmap` of 512 MB and first write to every 4 KB page.
- **memcpy:** 8 copies of 256 MB.

The memory tests run last, because afterwards the process stays large and `fork` would cost more.

**Conditions.**
- L1 and L2 measurements were taken one VM at a time. Only the user's desktop stayed running on the host.
- The host has a busy loop between `dbus-daemon` and `xfce4-power-manager`: 27% + 17% CPU, with 5.5 h already accumulated by `dbus-daemon`. On top of that, Telegram at 20% and a root `find`. That is about one busy core, which weighs on the L0 column (timer p99 and maximum, all-thread CPU) and slightly on all the others.
- L0 and L1 have one run each, the L2s two to three.
- The images of Windows, L1 FreeBSD and L1 Ubuntu all sit on the USB G-DRIVE (`/mnt/da1p2`): every disk goes through the same physical drive.
- L2 networking:
  - WSL uses Windows NAT (GNS);
  - the L2 under KVM uses QEMU user networking (slirp);
  - the L2 under bhyve uses the L1's bridge.

**Mistakes made during the campaign, found and fixed** (the bad files are tagged `.NON-VALIDO-*` and kept out of
the tables):
1. **`memcpy` optimised away by the compiler:** the first run reported 79 PB/s. The copy now goes through a `volatile` pointer.
2. **`fork` measured after the memory tests:** 35 ms instead of 0.6 ms. The tests were reordered.
3. **`winsat` without Hyper-V:** my script re-read the XML of the previous run, so CPU and memory came out identical to the last decimal. The XML is now deleted before each test, and the run was redone.
4. **L1 FreeBSD serial console:**
   - I took a marker from an old run for a new one;
   - zsh's `noclobber` refused `>`, so the "with VMX" run had never started.

   I now use unique markers and `>|`.
5. **`nc` without `-d`:** with stdin on a terminal, the client stayed open until the `timeout`, and the L1 FreeBSD download came out as "1 GB in exactly 120 s". Re-measured separately: 107 MB/s.
6. **Host `nc` queued:** a server busy with a stale connection left the L2 hanging for 20 minutes. The server now sends 1 GB and closes, and every `nc` has a `timeout`.

**Things touched for the campaign, and their state.**
- **Windows `.wslconfig`:** moved aside for Debian and put back. Identical to `wslconfig-freebsd.ini`.
- **`hypervisorlaunchtype`:** set to `Off`, then back to `Auto`.
- **Windows:** restarted as in the morning, with QEMU+bhyve `--qemu-sipi --audio`.
- **Launchers:**
  - G-DRIVE path `da0p2` → `da1p2`;
  - L1 FreeBSD `--senza-nesting` (no nesting);
  - L1 Ubuntu `--senza-gpu` (no GPU).

  The default behaviour is unchanged; the `.prima-*` copies sit alongside. These changes are not committed.
- **Copy of the user's FreeBSD (the L1 image) and L1 Ubuntu:** my files are reduced to zero bytes; the `~/claude-banco` and `~/claude-l2` directories remain. The L2 image is kept on the host in `confronto-kvm-bhyve/immagini/fb151-l2.raw.zst`.
- **Temporary services on the host** (HTTP 8765, `nc` 8766/8767): stopped.
- **List of approved tools:** archived as `APPROVATI-sequenza.sha256.archivio-20261118-prima-del-banco`, plus two lines.
