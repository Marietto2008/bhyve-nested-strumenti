#!/usr/local/bin/python3
# test-p3-verdetto.py -- Claude 01/11/2026. Collaudo di p3-verdetto.py, come utente collaudo. Esemplari REALI: lo
# stato.json e la forma della seriale di una sessione KUT vera (logs/A-s10-1/drv: "t.ttt PASS: ...", "SUMMARY: N tests",
# qemu_rc 1), il manifest della corsa vera dello stadio 11 (logs/qualifica-s11/corsa1) con la riga del piano cambiata.
# Ogni caso cambia una sola cosa e verifica esito E motivo.
# Uso: sudo -u collaudo python3 test-p3-verdetto.py <cartella nuova in collaudi>
import json, os, pwd, shutil, subprocess, sys
os.environ['PATH'] = '/bin:/usr/bin:/sbin:/usr/sbin:/mnt/linuxulator2/vm/nested-work/collaudo-bin'
if pwd.getpwuid(os.getuid()).pw_name != 'collaudo':
	print('STOP: le suite girano solo come utente collaudo'); raise SystemExit(2)
if shutil.which('sudo'):
	print('STOP: sudo raggiungibile dal collaudo'); raise SystemExit(2)
W = '/mnt/linuxulator2/vm/nested-work'
O = sys.argv[1]
if not O.startswith(W + '/collaudi/') or os.path.exists(O):
	print('cartella non valida o esistente'); raise SystemExit(2)
os.makedirs(O)
ST = json.load(open(W + '/logs/A-s10-1/drv/stato.json'))
ST['regole'] = []; ST['invii'] = []
MANV = open(W + '/logs/qualifica-s11/corsa1/manifest.txt').read()
import re
MAN = re.sub(r'^piano wsl modo --esegui ', 'piano p3 modo --esegui ', MANV, flags=re.M)
MAN = re.sub(r'^sonde \S+ ([0-9a-f]{64}) etichetta \S+$', r'sonde /x/sonde-wsl-v1.d \1 etichetta sonde-wsl-v1', MAN, flags=re.M)
assert 'piano p3 modo --esegui ' in MAN and 'stadio stadio11 firma oid 11111' in MAN
SER = ('0.512 P3 pte 0x3f7d008 v0 0x7f3e003 v1 0x7f3e203\n0.513 PASS: PTE a 4K della pagina dell\'operando\n0.520 PASS: VMXON\n'
       '0.521 PASS: VMPTRST senza contesa (0xffffffffffffffff)\n0.521 P3 riferimento cicli 41210\n'
       '1.402 PASS: round 1: VMPTRST completa con il valore giusto (0xffffffffffffffff)\n1.402 P3 round 1 cicli 2998412000 durata 3000000000 scritture 812000000\n'
       '2.290 PASS: round 2: VMPTRST completa con il valore giusto (0xffffffffffffffff)\n2.290 P3 round 2 cicli 2997130000 durata 3000000000 scritture 809000000\n'
       '3.177 PASS: round 3: VMPTRST completa con il valore giusto (0xffffffffffffffff)\n3.177 P3 round 3 cicli 2996900000 durata 3000000000 scritture 811000000\n'
       '3.178 PASS: VMPTRST dopo la contesa\n3.180 SUMMARY: 7 tests\n')
SON = 'DTRACE_ATTIVO sonde-wsl-v1\nDTRACE_FINE\n'


def sessione(n, man=None, st=None, ser=None, son=None, err='', cont=None, p3='gla2gpa_restart_capped 0 41230\n', dmesg='', togli=()):
	d = os.path.join(O, n); os.makedirs(d + '/drv')
	f = {'manifest.txt': MAN if man is None else man, 'sonde.txt': SON if son is None else son, 'sonde-err.txt': err,
	     'contatori.txt': cont if cont is not None else 'fatal_latches 0 0\nnested_vept_mmio_unemulable 0 0\nnested_operand_fatal 0 0\n',
	     'contatori-p3.txt': p3, 'dmesg-sessione.txt': dmesg, 'drv/seriale.txt': SER if ser is None else ser,
	     'drv/stato.json': json.dumps(ST if st is None else st)}
	for k, v in f.items():
		if k not in togli:
			open(os.path.join(d, k), 'w').write(v)
	return d


nok = nko = 0


def caso(n, atteso, motivo, **k):
	global nok, nko
	d = sessione(n, **k)
	p = subprocess.run(['python3', W + '/p3-verdetto.py', d], capture_output=True, text=True)
	ok = p.returncode == atteso and motivo in p.stdout
	nok += ok; nko += not ok
	print('  %s %-30s uscita %d (attesa %d): %s' % ('ok    ' if ok else 'ERRATO', n, p.returncode, atteso, p.stdout.strip()[:150]))


def st_con(**kw):
	s = dict(ST); s.update(kw); return s


caso('pass', 0, 'correzione esercitata 41230 volte')
# INCONCLUSIVO: la correzione non esercitata, o evidenza insufficiente
caso('contatore_fermo', 5, 'la correzione NON e\' stata esercitata', p3='gla2gpa_restart_capped 7 7\n')
caso('contatore_illeggibile', 5, 'non numerico', p3='gla2gpa_restart_capped 0 illeggibile\n')
caso('contatore_sceso', 5, 'DIMINUITO', p3='gla2gpa_restart_capped 50 3\n')
caso('p3_assente', 5, 'contatori-p3.txt assente', togli=('contatori-p3.txt',))
caso('piano_wsl', 5, 'piano p3 modo --esegui', man=MANV)
caso('stadio10', 5, 'stadio11 con firma 11111', man=MAN.replace('stadio stadio11 firma oid 11111', 'stadio stadio10 firma oid 11011'))
caso('driver_non_valido', 5, 'driver non valida', st=st_con(valida=False, errori=['foto fallita']))
caso('qemu_rc_assente', 5, 'codice d\'uscita della QEMU assente', st={k: v for k, v in ST.items() if k != 'qemu_rc'})
caso('skip_una_cpu', 5, 'test saltato', ser='0.3 SKIP: servono 2 CPU (-smp 2): trovate 1\n0.3 SUMMARY: 1 tests, 1 skipped\n')
caso('dtrace_senza_fine', 5, 'manca DTRACE_FINE', son='DTRACE_ATTIVO sonde-wsl-v1\n')
caso('stderr_dtrace', 5, 'stderr', err='dtrace: 2 drops\n')
caso('controlli_mancanti', 5, 'attesi 7', ser=SER.replace('3.178 PASS: VMPTRST dopo la contesa\n', ''))
# FAIL: difetti osservati
caso('round_sbagliato', 1, 'controlli KUT falliti', ser=SER.replace('1.402 PASS: round 1', '1.402 FAIL: round 1').replace('SUMMARY: 7 tests', 'SUMMARY: 7 tests, 1 unexpected failures'))
caso('round_mancante', 1, 'round di contesa incompleti', ser=SER.replace('3.177 P3 round 3', '3.177 P3 rnd 3'))
caso('qemu_fallita', 1, 'codice QEMU 3', st=st_con(qemu_rc=3))
caso('timeout', 1, 'TIMEOUT del driver', st=st_con(timeout=True))
caso('latch_sonda', 1, 'sonde del latch', son='DTRACE_ATTIVO sonde-wsl-v1\nOPNDFATAL vcpu=0 stadio=4 err=14 rip=0x1 gla=0x2\nDTRACE_FINE\n')
caso('latch_contatori', 1, 'contatori del latch cambiati', cont='fatal_latches 0 1\nnested_vept_mmio_unemulable 0 0\nnested_operand_fatal 0 1\n')
caso('panic_dmesg', 1, 'dmesg', dmesg='panic: nested: loop su VM_EXITCODE_NESTED (vcpu0 rip=0x401000 count=2000000)\n')
caso('fail_e_fermo', 1, 'e INCONCLUSIVO', st=st_con(qemu_rc=3), p3='gla2gpa_restart_capped 0 0\n')
print('SUMMARY: %d ok, %d errati' % (nok, nko))
sys.exit(1 if nko else 0)
