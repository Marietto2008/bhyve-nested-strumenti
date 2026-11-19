# Known issues

Stated up front, so a failure on your machine can be told apart from a known limit.

1. **FreeBSD as the WSL2 guest (L2 under Hyper-V) can panic in `lapic_et_start`.** It is reproducible under
   timer-heavy load. The same workload under KVM as L0 has not panicked so far. Open.
2. **Windows networking sometimes starts without interrupts.** On some boots the virtio-net MSI-X table is
   written empty (address 0, data 0, masked) and the network stays down until the next boot. It correlates with
   Windows' weekly registry reorganisation, but provoking that reorganisation did not reproduce it. Open.
3. **Nested IPIs are slow.** Waking another CPU in an L2 costs 0.7–1.9 ms (3.8 µs on the host). This is the
   largest performance cost; see `RESULTS.md`.
4. **bhyve as an L1 hypervisor resolves L2 page faults slowly.** First-touch page faults are 71× slower than on the
   host (4× when the L1 is KVM).
5. **GPU passthrough together with nesting is fragile.** It works with an NVIDIA card in an Ubuntu L1. With
   Windows + Hyper-V it caused blue screens until a fix in the module, and it is not regularly tested.
6. **Windows without Hyper-V cannot run `winsat mem`** ("cannot measure the TSC frequency"). The likely cause is
   that the TSC-frequency CPUID leaves are not offered to the guest. Not verified.
7. **Tested on one machine only:** an i9-9900K (no APICv, no posted interrupts). Different CPUs may behave
   differently, which is the point of the smoke test.
