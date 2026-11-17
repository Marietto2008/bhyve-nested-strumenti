#!/usr/bin/env python3
# bsp-fermo-046.py -- claude 15/11/2026 (diagnosi Fable 046 §3). A VM bloccata, dal monitor di QEMU (QMP -> HMP):
# registri del vCPU scelto (default 0), disassemblato attorno a RIP, 64 parole da RSP, e una pagina attorno a RIP
# in esadecimale. Uso: sudo python3 bsp-fermo-046.py [vcpu]   (stampa su stdout)
import json, re, socket, sys

S = '/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock'
cpu = sys.argv[1] if len(sys.argv) > 1 else '0'
s = socket.socket(socket.AF_UNIX); s.settimeout(30); s.connect(S)
f = s.makefile('rw')
json.loads(f.readline())

def cmd(c, a=None):
    m = {'execute': c}
    if a:
        m['arguments'] = a
    f.write(json.dumps(m) + '\n'); f.flush()
    while True:
        r = json.loads(f.readline())
        if 'return' in r or 'error' in r:
            return r

def hmp(line):
    r = cmd('human-monitor-command', {'command-line': line})
    out = r.get('return', r)
    print('### ' + line)
    print(out if isinstance(out, str) else json.dumps(out))
    return out if isinstance(out, str) else ''

cmd('qmp_capabilities')
hmp('cpu ' + cpu)
regs = hmp('info registers')
rip = int(re.search(r'RIP=([0-9a-f]+)', regs).group(1), 16)
rsp = int(re.search(r'RSP=([0-9a-f]+)', regs).group(1), 16)
hmp('x/24i 0x%x' % max(rip - 0x20, 0))
hmp('x/64gx 0x%x' % rsp)
hmp('x/64bx 0x%x' % (rip - 0x20))
