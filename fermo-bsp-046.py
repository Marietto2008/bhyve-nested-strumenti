#!/usr/bin/env python3
# fermo-bsp-046.py -- claude 15/11/2026 (diagnosi Fable 046 §3): a VM bloccata, dal monitor di QEMU (QMP):
# registri di tutti i vCPU, disassemblato attorno al RIP del BSP, 64 parole dallo stack del BSP, memoria attorno
# al RIP. Solo letture. Uso: fermo-bsp-046.py [socket]
import json, re, socket, sys
S = sys.argv[1] if len(sys.argv) > 1 else '/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock'
s = socket.socket(socket.AF_UNIX); s.settimeout(60); s.connect(S)
f = s.makefile('rw')
json.loads(f.readline())
def cmd(c, a=None):
    m = {'execute': c}
    if a: m['arguments'] = a
    f.write(json.dumps(m) + '\n'); f.flush()
    while True:
        r = json.loads(f.readline())
        if 'return' in r or 'error' in r: return r
def hmp(linea, cpu=0):
    r = cmd('human-monitor-command', {'command-line': linea, 'cpu-index': cpu})
    return r.get('return', str(r))
cmd('qmp_capabilities')
regs0 = hmp('info registers', 0)
def campo(nome):
    m = re.search(r'\b' + nome + r'=([0-9a-fA-F]+)', regs0)
    return int(m.group(1), 16) if m else None
rip, rsp, cr3 = campo('RIP'), campo('RSP'), campo('CR3')
print('=== info registers, vCPU 0 (BSP)'); print(regs0)
print('RIP=%s RSP=%s CR3=%s' % tuple(hex(v) if v is not None else '?' for v in (rip, rsp, cr3)))
if rip is not None:
    print('=== disassemblato da RIP-0x40 (puo\' partire a meta\' di un\'istruzione) e da RIP')
    print(hmp('x/24i 0x%x' % (rip - 0x40), 0))
    print(hmp('x/16i 0x%x' % rip, 0))
    print('=== byte attorno a RIP')
    print(hmp('x/64xb 0x%x' % (rip - 0x20), 0))
if rsp is not None:
    print('=== 64 parole da RSP')
    print(hmp('x/64gx 0x%x' % rsp, 0))
for c in range(1, 8):
    print('=== info registers, vCPU %d' % c)
    print(hmp('info registers', c))
