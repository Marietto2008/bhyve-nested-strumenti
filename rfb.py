#!/usr/bin/env python3
# rfb.py -- Claude 12/11/2026: client RFB minimo (sicurezza None) per la VNC di QEMU della vm0:13 (127.0.0.1:5913).
#   rfb.py foto <file.ppm>        cattura lo schermo intero (formato 32 bpp, codifica raw)
#   rfb.py scrivi "<testo>" [invio]  manda il testo tasto per tasto (keysym ASCII), con invio finale se richiesto
# Senza librerie, come clicca.py della Cubie (feedback_verificare_gui_con_click_rfb_e_grim).
import socket, struct, sys, time

def conn(host='127.0.0.1', port=5913):
    s = socket.create_connection((host, port), 10)
    s.recv(12); s.sendall(b'RFB 003.008\n')
    n = s.recv(1)[0]; tipi = s.recv(n)
    if 1 not in tipi:
        raise SystemExit('il server non offre la sicurezza None: %r' % tipi)
    s.sendall(b'\x01'); esito = s.recv(4)
    if esito != b'\x00\x00\x00\x00':
        raise SystemExit('autenticazione rifiutata')
    # ClientInit: 0 = esclusivo. QEMU rifiuta un client condiviso se TigerVNC e' collegato in esclusiva
    # (12/11: chiusura subito dopo ClientInit); cosi' il visore viene staccato e va riaperto dopo.
    s.sendall(b'\x00')
    w, h = struct.unpack('>HH', leggi(s, 4)); leggi(s, 16)
    nl = struct.unpack('>I', leggi(s, 4))[0]; leggi(s, nl)
    return s, w, h

def leggi(s, n):
    b = b''
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c:
            raise SystemExit('connessione chiusa')
        b += c
    return b

def tasto(s, ks):
    s.sendall(struct.pack('>BBxxI', 4, 1, ks)); time.sleep(0.03)
    s.sendall(struct.pack('>BBxxI', 4, 0, ks)); time.sleep(0.03)

def foto(path):
    s, w, h = conn()
    # SetPixelFormat: 32 bpp, profondita' 24, little endian, true colour, rosso 16, verde 8, blu 0
    s.sendall(struct.pack('>BxxxBBBBHHHBBBxxx', 0, 32, 24, 0, 1, 255, 255, 255, 16, 8, 0))
    s.sendall(struct.pack('>BxHi', 2, 1, 0))     # SetEncodings: solo raw
    s.sendall(struct.pack('>BBHHHH', 3, 0, 0, 0, w, h))
    img = bytearray(w * h * 3); fatto = 0
    while fatto < w * h:
        t = leggi(s, 1)[0]
        if t != 0:
            continue
        leggi(s, 1); nr = struct.unpack('>H', leggi(s, 2))[0]
        for _ in range(nr):
            x, y, rw, rh, enc = struct.unpack('>HHHHi', leggi(s, 12))
            px = leggi(s, rw * rh * 4)
            for r in range(rh):
                for c in range(rw):
                    o = (r * rw + c) * 4; d = ((y + r) * w + x + c) * 3
                    img[d:d + 3] = bytes((px[o + 2], px[o + 1], px[o]))
            fatto += rw * rh
    open(path, 'wb').write(b'P6 %d %d 255\n' % (w, h) + bytes(img))
    print('%dx%d -> %s' % (w, h, path))

if __name__ == '__main__':
    if sys.argv[1] == 'foto':
        foto(sys.argv[2])
    elif sys.argv[1] == 'scrivi':
        s, w, h = conn()
        for ch in sys.argv[2]:
            tasto(s, ord(ch))
        if len(sys.argv) > 3 and sys.argv[3] == 'invio':
            tasto(s, 0xff0d)
        print('mandati %d caratteri' % len(sys.argv[2]))
