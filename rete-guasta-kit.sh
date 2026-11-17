#!/bin/sh
# rete-guasta-kit.sh -- claude 17/11/2026 (Fable 067 par. 5.3.4): kit di raccolta quando Windows vm0:13 parte senza rete.
# Da lanciare A VM VIVA, prima di qualunque spegnimento (anche ACPI): raccoglie in dati-bhyve/rete-guasta-<ora>/
#   - QMP: info pci, info mtree -f, tabelle MSI-X di virtio-net e xHCI (xp, BAR lette da info pci), foto dello schermo;
#   - la firma nella traccia QEMU dell'avvio (scritture della tabella, smascheramenti, notify_masked) e la traccia stessa;
#   - registratore delle hypercall: codici e anello (prima che lo spegnimento o un nuovo avvio li azzeri);
#   - salva-contatori.sh con il motivo.
# Solo letture: non spegne, non riavvia, non tocca il modulo.
#   sudo sh rete-guasta-kit.sh
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
[ "$(id -u)" = 0 ] || { echo "serve root (la presa QMP e la traccia sono di root)"; exit 4; }
Q=/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock
[ -S $Q ] || { echo "presa QMP assente: QEMU non sta girando ($Q)"; exit 4; }
B=/mnt/linuxulator2/vm/confronto-kvm-bhyve
O=$B/dati-bhyve/rete-guasta-$(date +%Y%m%d-%H%M%S)
mkdir -p $O || exit 4
echo "raccolta in $O"

python3.12 - $Q $O <<'FINE_KIT_QMP'
import json, re, socket, sys
q, o = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX); s.connect(q)
f = s.makefile('rw'); f.readline()
def cmd(c, **a):
    f.write(json.dumps({'execute': c, 'arguments': a} if a else {'execute': c}) + '\n'); f.flush()
    while True:
        r = json.loads(f.readline())
        if 'return' in r or 'error' in r:
            return r
def hmp(l):
    r = cmd('human-monitor-command', **{'command-line': l})
    return r.get('return', str(r))
cmd('qmp_capabilities')
pci = hmp('info pci')
open(o + '/info-pci.txt', 'w').write(pci)
open(o + '/info-mtree-f.txt', 'w').write(hmp('info mtree -f'))
# BAR della tabella MSI-X: virtio-net (1af4:1000) BAR1, xHCI (1b36:000d) BAR0 + 0x3000 (tabella di QEMU; nel guasto del
# 17/11 08:20 la BAR0 dell'xHCI era «not mapped»: si annota, la tabella allora non si legge)
out = []
for nome, ven, bar, off in (('virtio-net', '1af4:1000', 'BAR1', 0), ('xhci', '1b36:000d', 'BAR0', 0x3000)):
    blocco = [b for b in re.split(r'\n(?=  Bus )', pci) if 'PCI device ' + ven in b]
    m = re.search(bar + r': (?:32|64) bit (?:prefetchable )?memory at (0x[0-9a-f]+)', blocco[0]) if blocco else None
    if not m:
        out.append('%s: %s non montata o assente in info pci (vedi info-pci.txt)\n' % (nome, bar))
        continue
    base = int(m.group(1), 16) + off
    out.append('==== %s tabella MSI-X a %#x\n%s\n' % (nome, base, hmp('xp /32wx %#x' % base)))
open(o + '/tabelle-msix.txt', 'w').write(''.join(out))
print(cmd('screendump', filename=o + '/schermo.ppm'))
print(cmd('query-status'))
FINE_KIT_QMP

# firma nella traccia QEMU di questo avvio (la piu' recente)
T=$(ls -t /mnt/linuxulator2/vm/wsl2-freebsd-work/logs/vm0-13-qemu-trace-*.txt 2>/dev/null | head -1)
if [ -n "$T" ]; then
	{
		echo "traccia: $T"
		echo "virtio-net: scritture della tabella $(grep -a -c 'msix_table_write dev virtio-net' $T), smascheramenti $(grep -a -c 'msix_mask_update dev virtio-net.*1->0' $T), notify_masked $(grep -a -c 'msix_notify_masked dev virtio-net' $T)"
		echo "xhci: scritture della tabella $(grep -a -c 'msix_table_write dev qemu-xhci' $T), smascheramenti $(grep -a -c 'msix_mask_update dev qemu-xhci.*1->0' $T)"
		echo "prime scritture della tabella di virtio-net:"
		grep -a -E 'msix_table_write dev virtio-net' $T | head -16
	} > $O/firma-traccia.txt
	cp -p $T $O/
fi

# registratore delle hypercall: prima di qualunque spegnimento
if sysctl -n hw.vmm.vmx.nested_hcall_reg >/dev/null 2>&1; then
	sysctl -n hw.vmm.vmx.nested_hcall_codici > $O/hcall-codici.txt 2>&1
	sysctl -n hw.vmm.vmx.nested_hcall_anello > $O/hcall-anello.txt 2>&1
	echo "voci $(sysctl -n hw.vmm.vmx.nested_hcall_voci) senza_ritorno $(sysctl -n hw.vmm.vmx.nested_hcall_senza_ritorno)" >> $O/hcall-codici.txt
else
	echo "registratore delle hypercall assente nel modulo caricato" > $O/hcall-codici.txt
fi
sh $B/strumenti/salva-contatori.sh "RETE GUASTA, kit di raccolta ($O)" > $O/contatori.txt
chown -R marietto $O 2>/dev/null
echo "fatto:"; ls -la $O | tail -n +2
cat $O/firma-traccia.txt 2>/dev/null | head -4
grep -o -E '0x7[cde]:[0-9]+/[0-9]+' $O/hcall-codici.txt 2>/dev/null
