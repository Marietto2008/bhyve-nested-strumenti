# Nested VMX for bhyve — reproduction kit

This kit lets you check, on your own machine, whether the nested-virtualization work for bhyve runs there, and
compare your numbers with mine. It is deliberately small. Read `KNOWN-ISSUES.md` and `AI-USAGE.md` before relying
on anything here.

## What you need

- An Intel CPU with VT-x, EPT and unrestricted guest. VMCS shadowing helps but is optional. AMD (SVM) is **not**
  supported by this work.
- A FreeBSD 16-CURRENT host whose kernel matches the source tree below (the module is built against it).
- `edk2-bhyve` (UEFI firmware), a C compiler, and about 8 GB of free disk for the test.

## Source

| repository | branch | commit | what |
|---|---|---|---|
| github.com/Marietto2008/freebsd-src | `vmm-nested-16` | `d7d425762fcb` | vmm with nested VMX, bhyve, libvmmapi (reference branch) |
| same | `vmm-nested-16-lavoro` | `2c665a22bfc7` | same tree, with the full work history; my module was built from here |
| same | `vmm-qemu-mods-16-ottobre2026` | `e5264af42700` | the base without nesting |
| github.com/Marietto2008/qemu | `accel-vmm-freebsd-nested` | `3f516059c9` | QEMU with the bhyve accelerator (only needed for the Windows/WSL2 path) |

## Build and load

```sh
git clone -b vmm-nested-16 https://github.com/Marietto2008/freebsd-src.git
cd freebsd-src
# the module (named vmm-restore.ko), against your running kernel's build directory
make -C sys/modules/vmm KERNBUILDDIR=/usr/obj/usr/src/amd64.amd64/sys/YOURKERNEL
# libvmmapi, bhyve and bhyvectl from the same tree (they must see this tree's headers)
```

> **Caveat.** These build steps are taken from `tools/nested/build.sh` and have not yet been tried on a clean
> machine. The module is built against the running kernel; with a 16-CURRENT kernel from a different point in
> time it may not build or load. The safe path is to build and install the kernel from this same branch
> (`make buildkernel installkernel KERNCONF=...`), then the module and bhyve. Reports of what breaks are welcome.

`tools/nested/build.sh` in the branch does all of the above into a staging directory (copy
`tools/nested/nested.env.example` to `nested.env` first). Its comments are in Italian.

Load the module **instead of** the stock `vmm.ko`, for example with `vmm_name="vmm-restore"` and
`vmm_load="YES"` in `/boot/loader.conf`. Before creating a nested VM, set:

```sh
sysctl hw.vmm.vmx.vept_keep=1     # keep shadow EPT roots across L1 INVEPT; read when the VM is created
```

All my results used `vept_keep=1`, `vept_keep_rientro=2` and `tsc_sync=1` (the last two are the defaults), with
`nested_shadow_vmcs=0`. A VM gets nested VMX only when bhyve is started with `-o x86.nested_virt=true`.

## Run the smoke test

```sh
sh host-manifest.sh > manifest.txt                       # describe your host (run as root)
BHYVE=/path/to/branch/bhyve sh smoke-test.sh /some/workdir
```

`smoke-test.sh` boots the official FreeBSD 15.1 cloud image as L1 with nesting, checks that the L1 can use VMX,
boots an L2 kernel inside it, runs the benchmark, and prints PASS/FAIL. It needs no network inside the guests and
touches nothing outside its work directory. On my host it ends with `ALL PASSED` (see `RESULTS.md`).

When you report a result, please attach `manifest.txt` and the smoke-test output.

## Files

| file | purpose |
|---|---|
| `host-manifest.sh` | CPU, microcode, board, BIOS, VMX MSRs, module and binary hashes, `hw.vmm` settings |
| `smoke-test.sh` | the one-command test described above |
| `claude-banco.c` | the benchmark (same binary at every level; output labels are Italian: `BANCO` = bench, `Mpassi/s` = million steps/s) |
| `RESULTS.md` | my reference numbers and the three findings worth attention |
| `KNOWN-ISSUES.md` | what still fails |
| `AI-USAGE.md` | how AI was used in this work |
| `full-report/` | the long report and the raw data behind every number |
