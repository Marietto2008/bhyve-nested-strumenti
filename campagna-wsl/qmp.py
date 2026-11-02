#!/usr/bin/env python3
# qmp.py -- Claude 03/11/2026. Un comando QMP alla VM vm0-13 (A): qmp.py system_powerdown | qmp.py hmp "info pci"
import json, socket, sys
S = '/mnt/linuxulator2/vm/wsl2-freebsd-work/vm0-13-qmp.sock'
s = socket.socket(socket.AF_UNIX); s.settimeout(20); s.connect(S)
f = s.makefile('rw')
json.loads(f.readline())
def cmd(c, a=None):
    m = {'execute': c}
    if a: m['arguments'] = a
    f.write(json.dumps(m) + '\n'); f.flush()
    while True:
        r = json.loads(f.readline())
        if 'return' in r or 'error' in r: return r
cmd('qmp_capabilities')
if sys.argv[1] == 'hmp':
    r = cmd('human-monitor-command', {'command-line': sys.argv[2]})
    print(r.get('return', r))
else:
    print(cmd(sys.argv[1]))
