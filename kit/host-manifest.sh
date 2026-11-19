#!/bin/sh
# host-manifest.sh -- describe the host a nested-bhyve result was measured on.
#
# Prints a plain-text manifest: OS and kernel, CPU and microcode, board and BIOS, VMX capability MSRs, the loaded
# vmm module and its hash, the bhyve/QEMU binaries used, and every writable hw.vmm setting. Attach its output to
# any result you report, so results from different machines can be compared.
#
# Usage (as root, for the MSR reads):  sh host-manifest.sh > manifest.txt
#        BHYVE=/path/to/bhyve QEMU=/path/to/qemu-system-x86_64 sh host-manifest.sh > manifest.txt
# It reads only; it changes nothing. It does not print the hostname or any network address.
set -u
LC_ALL=C; export LC_ALL

sec() { printf '\n== %s\n' "$1"; }
sha() { [ -f "$1" ] && printf '%s  %s\n' "$(sha256 -q "$1")" "$1" || printf 'missing  %s\n' "$1"; }
msr() {	# msr <hex address> <name>; needs root and cpuctl(4)
	v=$(cpucontrol -m "$1" /dev/cpuctl0 2>/dev/null | awk '{print $3, $4}')
	printf '%-8s %-28s %s\n' "$1" "$2" "${v:-unreadable (run as root, kldload cpuctl)}"
}

echo "host-manifest 1.0, $(date -u +%Y-%m-%dT%H:%M:%SZ)"

sec "OS"
echo "release:    $(uname -sr)  (osreldate $(sysctl -n kern.osreldate))"
echo "kernel:     $(sysctl -n kern.ident), $(uname -v | sed 's/[[:space:]]*[^[:space:]]*@[^[:space:]]*//')"
echo "memory:     $(( $(sysctl -n hw.physmem) / 1048576 )) MiB"

sec "CPU"
echo "model:      $(sysctl -n hw.model)"
echo "threads:    $(sysctl -n hw.ncpu)"
grep -m1 -E '^ *Origin=' /var/run/dmesg.boot 2>/dev/null | sed 's/^ */signature:  /'
kldload -n cpuctl 2>/dev/null
v=$(cpucontrol -m 0x8b /dev/cpuctl0 2>/dev/null | awk '{print $3}')
echo "microcode:  revision ${v:-unreadable (run as root)} (high dword of MSR 0x8b)"
grep -m1 'VT-x:' /var/run/dmesg.boot 2>/dev/null | sed 's/^ */vt-x:       /'
grep -m1 -E 'Features2=' /var/run/dmesg.boot 2>/dev/null | sed 's/^ */features2:  /'

sec "Board and firmware (SMBIOS)"
for k in system.maker system.product planar.maker planar.product bios.vendor bios.version bios.reldate; do
	printf '%-16s %s\n' "$k:" "$(kenv -q smbios.$k 2>/dev/null)"
done

sec "VMX capability MSRs (cpu0)"
msr 0x3a  IA32_FEATURE_CONTROL
msr 0x480 VMX_BASIC
msr 0x481 VMX_PINBASED_CTLS
msr 0x482 VMX_PROCBASED_CTLS
msr 0x483 VMX_EXIT_CTLS
msr 0x484 VMX_ENTRY_CTLS
msr 0x485 VMX_MISC
msr 0x48b VMX_PROCBASED_CTLS2
msr 0x48c VMX_EPT_VPID_CAP
msr 0x48d VMX_TRUE_PINBASED_CTLS
msr 0x48e VMX_TRUE_PROCBASED_CTLS
msr 0x48f VMX_TRUE_EXIT_CTLS
msr 0x490 VMX_TRUE_ENTRY_CTLS
msr 0x491 VMX_VMFUNC

sec "vmm module"
kldstat -v 2>/dev/null | awk '/vmm/ && /\.ko/ {print}' | head -3
m=$(kldstat 2>/dev/null | awk '/vmm/ && /\.ko/ {print $NF; exit}')
if [ -n "$m" ]; then
	for d in $(dirname "$(sysctl -n kern.bootfile)") /boot/modules; do [ -f "$d/$m" ] && sha "$d/$m"; done
else
	echo "no vmm module loaded"
fi

sec "Binaries"
sha "${BHYVE:-/usr/sbin/bhyve}"
[ -n "${QEMU:-}" ] && sha "$QEMU"

sec "Writable hw.vmm settings"
sysctl -W hw.vmm 2>/dev/null | grep -v -E '^hw\.vmm\.(create|destroy):' | sort
