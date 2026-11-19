# Reference results (i9-9900K, FreeBSD 16-CURRENT host)

Measured on 18–19 Nov 2026 with the same static `claude-banco` binary at every level. The host details are in
`full-report/` and can be regenerated with `host-manifest.sh`.

## Three findings worth attention

1. **One level of bhyve is essentially free.** A FreeBSD or Ubuntu guest runs CPU-bound code, fork/exec and memcpy
   at host speed. Exposing VMX to the guest costs nothing measurable.
2. **In every nested (L2) setup the dominant cost is waking another CPU.** A pipe round trip between two CPUs takes
   3.8 µs on the host and 1–1.9 ms in the L2, whatever the L1 hypervisor. Without APICv every IPI goes through L0.
3. **The L1 hypervisor matters more than bhyve underneath.** With the same FreeBSD 15.1 L2 image, first-touch page
   faults are 4× slower than on the host under KVM, but 71× slower under bhyve.

## Key numbers

| test | host | L1 FreeBSD on bhyve | L2 FreeBSD, bhyve in bhyve | L2 FreeBSD, KVM in bhyve | L2 FreeBSD, Hyper-V/WSL2 in bhyve |
|---|---:|---:|---:|---:|---:|
| CPU, 1 thread (Msteps/s) | 467 | 465 | 403 | 410 | 284–320 |
| fork + exec (µs) | 554 | 559 | 4,695 | 2,987 | 4,851–6,943 |
| pipe round trip between 2 CPUs (µs) | 3.8 | 3.9 | 1,601 | 1,037 | 1,798–1,869 |
| first write to 4 KB pages (k/s) | 743 | 1,147 | 10.5 | 183 | 26–31 |
| memcpy, 1 thread (GB/s) | 11.5 | 11.8 | 9.0 | 9.6 | 0.8–1.7 |

## Smoke test on this host

`smoke-test.sh` output on 19 Nov 2026 (L1 = FreeBSD 15.1 cloud image, 4 vCPUs, 4 GB):

```
PASS  l1_boots
PASS  vmx_in_l1
PASS  l2_kernel_boots
PASS  benchmark_ran
SMOKE: l1 FreeBSD 15.1-RELEASE 4 cpus vm_guest=kvm
SMOKE: vtx VT-x: PAT,HLT,MTF,PAUSE,EPT,UG,VPID
SMOKE: l2 mountroot after 10s
SMOKE: l2 Hypervisor: Origin = "bhyve bhyve "
BANCO inizio 4 CPU, vm_guest kvm, Intel(R) Core(TM) i9-9900K CPU @ 3.60GHz, 5 s per prova
BANCO cpu1 466.0 Mpassi/s
BANCO cpuN 1862.0 Mpassi/s (4 thread, 4.00 x cpu1)
BANCO syscall 143.7 ns
BANCO fork 564.9 us
BANCO pipe 3.9 us mediana, p99 6.6, max 68.2
BANCO timer 29 us mediana, p99 45, p99.9 74, max 181 (19412 pause su 4 CPU)
BANCO pagine 464.5 kpagine/s
BANCO memcpy 10.30 GB/s
BANCO fine
ALL PASSED
```

If your numbers differ a lot, `host-manifest.sh` output is the first thing to compare: CPU features (APICv,
posted interrupts, VMCS shadowing) and microcode change the picture.
