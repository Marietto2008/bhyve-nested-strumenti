#!/usr/bin/env python3
# qmp-hmp.py <socket> <comando HMP>: un comando del monitor umano via QMP (sola lettura se il comando lo e')
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile('rw')
f.readline()
def cmd(o):
    f.write(json.dumps(o) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if 'return' in r or 'error' in r: return r
cmd({"execute": "qmp_capabilities"})
r = cmd({"execute": "human-monitor-command", "arguments": {"command-line": " ".join(sys.argv[2:])}})
print(r.get('return', r))
