#!/bin/sh
# smoke-test.sh -- one-command check of nested virtualization on a FreeBSD/bhyve host.
#
# What it does, unattended, and with no network inside the guests:
#   1. writes host-manifest.txt (hardware, firmware, microcode, VMX MSRs, module hashes, settings);
#   2. downloads the official FreeBSD 15.1 BASIC-CLOUDINIT image once and verifies it against FreeBSD's CHECKSUM;
#   3. boots it as L1 under bhyve with VMX exposed (-o x86.nested_virt=true), with a cloud-init seed that
#      a. checks that the L1 sees VT-x and can initialise vmm(4)            -> test "vmx_in_l1"
#      b. boots an L2 inside the L1 with the stock 15.1 bhyve (the L1's own kernel via bhyveload -h /, no disk)
#         and waits for its "mountroot>" prompt                              -> test "l2_kernel_boots"
#      c. runs claude-banco (CPU, syscall, fork, IPI round trip, timer, page faults, memcpy) in the L1
#      d. powers off;
#   4. prints PASS/FAIL per test and the benchmark lines; everything is also kept in $WORK.
# It creates one VM named smoke-l1 and touches nothing outside $WORK. Exit status 0 = all tests passed.
#
# Requirements: root; a vmm module with nested VMX support loaded (branch vmm-nested-16); the bhyve built from that
# branch (stock bhyve does not know x86.nested_virt); edk2-bhyve (BHYVE_UEFI_CODE.fd); cc; ~8 GB free in $WORK.
#
# Usage:  sh smoke-test.sh [workdir]           (default ./smoke-work)
#         BHYVE=/path/to/nested/bhyve sh smoke-test.sh
set -u
LC_ALL=C; export LC_ALL
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${1:-./smoke-work}
BHYVE=${BHYVE:-/usr/sbin/bhyve}
UEFI=${UEFI:-/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd}
VM=smoke-l1
NMDM=${NMDM:-47}
TIMEOUT=${TIMEOUT:-900}
REL=15.1
IMG=FreeBSD-$REL-RELEASE-amd64-BASIC-CLOUDINIT-ufs.raw
URL=https://download.freebsd.org/releases/VM-IMAGES/$REL-RELEASE/amd64/Latest

die() { echo "smoke-test: $*" >&2; exit 2; }
[ "$(id -u)" = 0 ] || die "run as root"
[ -x "$BHYVE" ] || die "bhyve not found: $BHYVE (set BHYVE=)"
[ -f "$UEFI" ] || die "UEFI firmware not found: $UEFI (pkg install edk2-bhyve)"
[ -e /dev/vmm/$VM ] && die "a VM named $VM already exists; destroy it first (bhyvectl --destroy --vm=$VM)"
kldstat -q -m vmm || die "vmm is not loaded (load the nested-capable vmm module first)"
mkdir -p "$WORK" || die "cannot create $WORK"
WORK=$(cd "$WORK" && pwd)
LOG=$WORK/console.log

echo "== 1/4 host manifest -> $WORK/host-manifest.txt"
BHYVE=$BHYVE sh "$HERE/host-manifest.sh" > "$WORK/host-manifest.txt" 2>&1

echo "== 2/4 FreeBSD $REL image"
if [ ! -f "$WORK/$IMG.xz" ]; then
	fetch -o "$WORK/$IMG.xz" "$URL/$IMG.xz" || die "download failed"
fi
fetch -q -o "$WORK/CHECKSUM.SHA256" "$URL/CHECKSUM.SHA256" || die "cannot fetch CHECKSUM.SHA256"
want=$(sed -n "s/^SHA256 ($IMG.xz) = //p" "$WORK/CHECKSUM.SHA256")
[ -n "$want" ] && [ "$(sha256 -q "$WORK/$IMG.xz")" = "$want" ] || die "image checksum mismatch"
echo "   checksum ok"
xz -dc "$WORK/$IMG.xz" > "$WORK/l1.raw" || die "decompression failed"	# fresh disk on every run

echo "== 3/4 seed and L1 boot (timeout ${TIMEOUT}s)"
mkdir -p "$WORK/seed"
cc -O2 -static -pthread -o "$WORK/seed/claude-banco" "$HERE/claude-banco.c" || die "cannot build claude-banco"
printf 'instance-id: smoke-%s\nlocal-hostname: smoke-l1\n' "$(date +%s)" > "$WORK/seed/meta-data"
cat > "$WORK/seed/user-data" <<'END_OF_USER_DATA'
#!/bin/sh
# runs once inside the L1 at first boot (nuageinit); all output goes to the serial console
exec > /dev/console 2>&1
say() { echo "SMOKE: $*"; }
echo "SMOKE-BEGIN"
say l1 "$(uname -sr)" "$(sysctl -n hw.ncpu) cpus" "vm_guest=$(sysctl -n kern.vm_guest)"
dmesg | grep -m1 'VT-x:' | sed 's/^ */SMOKE: vtx /'
kldload -n vmm nmdm
say vmx_initialized "$(sysctl -n hw.vmm.vmx.initialized 2>/dev/null || echo 0)"
# L2: the L1's own kernel, loaded from the L1 filesystem, no disk: it must reach the root-mount prompt
bhyvectl --destroy --vm=l2 >/dev/null 2>&1
( exec < /dev/nmdm0B; stty raw -echo; timeout 120 cat > /tmp/l2.log ) &
sleep 1
if timeout 60 bhyveload -h / -m 512M -c /dev/nmdm0A -e autoboot_delay=0 l2 >/dev/null 2>&1; then
	timeout 90 bhyve -c 1 -m 512M -H -s 0,hostbridge -s 31,lpc -l com1,/dev/nmdm0A l2 >/dev/null 2>&1 &
	# the kernel found no root disk (expected: the L2 has none) and stopped at the root-mount prompt; the
	# prompt has no newline, so the help text printed just before it counts as well
	M='mountroot>|Manual root filesystem specification'
	i=0; while [ $i -lt 90 ] && ! grep -q -E "$M" /tmp/l2.log 2>/dev/null; do sleep 1; i=$((i + 1)); done
	grep -q -E "$M" /tmp/l2.log && say l2 mountroot "after ${i}s" || say l2 no-mountroot
	grep -m1 -E 'Hypervisor: Origin' /tmp/l2.log | sed 's/^ */SMOKE: l2 /'
	tr -d '\r' < /tmp/l2.log | grep -v '^$' | tail -12 | sed 's/^/SMOKE: l2log /'
	pkill -f 'bhyve: l2' ; sleep 2; bhyvectl --destroy --vm=l2 >/dev/null 2>&1
else
	say l2 bhyveload-failed
fi
mkdir -p /tmp/seed
mount -t cd9660 /dev/iso9660/cidata /tmp/seed 2>/dev/null || mount -t cd9660 /dev/cd0 /tmp/seed
cp /tmp/seed/claude-banco /tmp/claude-banco && /tmp/claude-banco 5
echo "SMOKE-END"
shutdown -p now
END_OF_USER_DATA
makefs -t cd9660 -o rockridge -o label=cidata "$WORK/seed.iso" "$WORK/seed" >/dev/null || die "makefs failed"

kldload -n nmdm
( exec < /dev/nmdm${NMDM}B; stty raw -echo; exec cat ) > "$LOG" 2>&1 &
READER=$!
"$BHYVE" -c 4 -m 4G -w -H -A -o x86.nested_virt=true \
	-s 0,hostbridge -s 3,virtio-blk,"$WORK/l1.raw" -s 4,ahci-cd,"$WORK/seed.iso" -s 31,lpc \
	-l com1,/dev/nmdm${NMDM}A -l bootrom,"$UEFI" $VM > "$WORK/bhyve.log" 2>&1 &
BPID=$!
t=0
while [ $t -lt "$TIMEOUT" ] && kill -0 $BPID 2>/dev/null && ! grep -q '^SMOKE-END' "$LOG"; do sleep 5; t=$((t + 5)); done
# give the guest time to power off by itself, then clean up
i=0; while [ $i -lt 60 ] && kill -0 $BPID 2>/dev/null; do sleep 2; i=$((i + 1)); done
kill -0 $BPID 2>/dev/null && { kill -TERM $BPID; sleep 5; }
bhyvectl --destroy --vm=$VM >/dev/null 2>&1
kill $READER 2>/dev/null

echo "== 4/4 results (console: $LOG)"
tr -d '\r' < "$LOG" > "$LOG.txt"
rc=0
check() {	# check <test> <pattern>
	if grep -q -E "$2" "$LOG.txt"; then echo "PASS  $1"; else echo "FAIL  $1"; rc=1; fi
}
check l1_boots         '^SMOKE-BEGIN'
check vmx_in_l1        '^SMOKE: vmx_initialized 1'
check l2_kernel_boots  '^SMOKE: l2 mountroot'
check benchmark_ran    '^BANCO fine'
grep -E '^SMOKE: (l1|vtx|l2) ' "$LOG.txt"
grep -E '^BANCO ' "$LOG.txt"
[ $rc = 0 ] && echo "ALL PASSED" || echo "SOME TESTS FAILED (see $LOG and $WORK/bhyve.log)"
exit $rc
