#!/usr/bin/env python3.12
# riorg-intestazione.py -- claude 17/11/2026 (Fable 073 par. 2.3): prepara l'intestazione (blocco base regf, 512 byte) di un
# hive con l'ora dell'ultima riorganizzazione (FILETIME a 0xA8, verificata il 17/11 contro i Kernel-General 15) spostata
# indietro di GIORNI, cosi' al prossimo avvio Windows lo riorganizza. Legge dall'immagine raw (l'overlay e' appena creato:
# stesso contenuto) SOLO dopo i controlli: firma regf, sequenze uguali (hive chiuso pulito), somma di controllo valida,
# 0xA8 entro 10 minuti dall'ora attesa. Somma ricalcolata (XOR dei primi 127 dword, a 0x1FC).
#   riorg-intestazione.py <immagine raw> <offset> <ora attesa UTC AAAA-MM-GG HH:MM:SS> <file d'uscita> [giorni=8]
# Uscita: 0 file scritto | 4 controllo fallito, nulla scritto
import datetime, struct, sys

img, off, atteso, uscita = sys.argv[1], int(sys.argv[2], 0), sys.argv[3], sys.argv[4]
giorni = int(sys.argv[5]) if len(sys.argv) > 5 else 8
EPOCA = datetime.datetime(1601, 1, 1)


def ft(v):
    return EPOCA + datetime.timedelta(microseconds=v // 10)


def somma(b):
    x = 0
    for i in range(127):
        x ^= struct.unpack_from('<I', b, i * 4)[0]
    return 0xfffffffe if x == 0xffffffff else (1 if x == 0 else x)


with open(img, 'rb') as f:
    f.seek(off)
    b = bytearray(f.read(512))
s1, s2 = struct.unpack_from('<II', b, 4)
a8 = struct.unpack_from('<Q', b, 0xa8)[0]
att = datetime.datetime.strptime(atteso, '%Y-%m-%d %H:%M:%S')
errori = []
if b[0:4] != b'regf':
    errori.append('firma %r' % bytes(b[0:4]))
if s1 != s2:
    errori.append('sequenze diverse %d/%d (hive non chiuso pulito)' % (s1, s2))
if struct.unpack_from('<I', b, 0x1fc)[0] != somma(b):
    errori.append('somma di controllo non valida')
if a8 == 0 or abs((ft(a8) - att).total_seconds()) > 600:
    errori.append('0xA8 = %s, atteso %s' % (ft(a8) if a8 else 0, att))
print('offset %#x: firma %r seq %d/%d 0xA8 %s' % (off, bytes(b[0:4]), s1, s2, ft(a8) if a8 else 0))
if errori:
    print('CONTROLLO FALLITO, nulla scritto: ' + '; '.join(errori))
    sys.exit(4)
nuovo = a8 - giorni * 86400 * 10**7
struct.pack_into('<Q', b, 0xa8, nuovo)
struct.pack_into('<I', b, 0x1fc, somma(b))
with open(uscita, 'wb') as f:
    f.write(b)
print('pronta: 0xA8 %s -> %s, somma %#010x' % (ft(a8), ft(nuovo), somma(b)))
