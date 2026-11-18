#!/usr/local/bin/python3
# ahci-diag-leggi.py: legge l'anello BHYVE_AHCI_DIAG del bhyve diagnostico
# (commit fedfff84290e) a VM ferma. Uso: ahci-diag-leggi.py FILE [ultimi_ms]
# Stampa le voci in ordine di sequenza, tempi in ms relativi all'ULTIMA voce
# (negativi = prima), e un riassunto per tipo.
import struct, sys

TIPI = {1: 'CMD', 2: 'DONE', 3: 'FIS', 4: 'MSI', 5: 'NOMSI', 6: 'WR', 7: 'RD', 8: 'GENI'}
HDR = struct.Struct('<IIII48x')
REC = struct.Struct('<QIHBB8I')

def main():
    f = open(sys.argv[1], 'rb').read()
    magic, recsize, nrec, idx = HDR.unpack_from(f, 0)
    assert magic == 0x31474441 and recsize == REC.size, (hex(magic), recsize)
    finestra = float(sys.argv[2]) if len(sys.argv) > 2 else None
    voci = []
    for i in range(nrec):
        ns, seq, typ, port, slot, *v = REC.unpack_from(f, HDR.size + i * recsize)
        if seq:
            voci.append((seq, ns, typ, port, slot, v))
    voci.sort()
    print(f'# voci scritte {idx}, nell anello {len(voci)} (capienza {nrec})')
    if not voci:
        return
    fine = voci[-1][1]
    cont = {}
    for seq, ns, typ, port, slot, v in voci:
        t = (ns - fine) / 1e6
        if finestra is not None and t < -finestra:
            continue
        nome = TIPI.get(typ, str(typ))
        cont[nome] = cont.get(nome, 0) + 1
        if nome == 'CMD':
            d = f'op=0x{v[0]:02x} c={v[1]>>7} ci={v[2]:08x} sact={v[3]:08x} pend={v[4]:08x} is={v[5]:08x} abar={v[6]:08x} lba/feat={v[7]:08x}'
        elif nome == 'DONE':
            d = f'err={v[0]} done={v[1]} more={v[2]} op=0x{v[3]:02x} ci={v[4]:08x} sact={v[5]:08x} pend={v[6]:08x} ncq={v[7]}'
        elif nome == 'FIS':
            d = f'tipo=0x{v[0]:02x} irq={v[1]:08x} pxis={v[2]:08x} pxie={v[3]:08x} ci={v[4]:08x} sact={v[5]:08x} nuovo_irq={v[6]} stato=0x{v[7]:02x}'
        elif nome == 'MSI':
            d = f'addr={v[0]:08x} data={v[1]:04x} IS={v[2]:08x} pxis/mask={v[3]:08x} ghc={v[4]:08x} msi_on={v[5]} via={v[6]} pxie={v[7]:08x}'
        elif nome == 'NOMSI':
            r = {1: 'is&ie=0', 2: 'GHC.IE=0', 3: 'IS gia acceso'}.get(v[0], v[0])
            d = f'perche={r} pxis={v[1]:08x} pxie={v[2]:08x} IS={v[3]:08x} ghc={v[4]:08x}'
        elif nome in ('WR', 'RD'):
            d = f'off=0x{v[0]:03x} val={v[1]:08x} size={v[2]}'
        elif nome == 'GENI':
            d = f'mask={v[0]:08x} IS={v[1]:08x} ghc={v[2]:08x}'
        else:
            d = ' '.join(f'{x:08x}' for x in v)
        print(f'{t:12.3f} #{seq:<9} {nome:5} p{port if port != 255 else "H"} s{slot:<2} {d}')
    print('# conteggi:', ' '.join(f'{k}={n}' for k, n in sorted(cont.items())))

main()
