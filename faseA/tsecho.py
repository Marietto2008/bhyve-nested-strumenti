#!/usr/bin/env python3
# Claude 23/10/2026 -- parere #33 §3: eco UDP con l'ora dell'host (CLOCK_REALTIME, ns),
# per allineare gli orologi di WSL2 (gapmon) e di FreeBSD. Risponde "t1 t2 t3":
# t1 dal cliente, t2 ricezione e t3 invio sull'host. Registra ogni scambio.
import socket, sys, time
porta = int(sys.argv[1]) if len(sys.argv) > 1 else 7123
log = open(sys.argv[2], "a", buffering=1) if len(sys.argv) > 2 else sys.stdout
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("0.0.0.0", porta))
while True:
    dati, da = s.recvfrom(128)
    t2 = time.clock_gettime_ns(time.CLOCK_REALTIME)
    t1 = dati.decode(errors="replace").strip()
    t3 = time.clock_gettime_ns(time.CLOCK_REALTIME)
    s.sendto(f"{t1} {t2} {t3}".encode(), da)
    log.write(f"{da[0]} {t1} {t2} {t3}\n")
