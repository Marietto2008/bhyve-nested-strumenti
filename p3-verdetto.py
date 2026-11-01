#!/usr/local/bin/python3
# p3-verdetto.py -- Claude 01/11/2026. Verdetto di UNA sessione del test di provocazione di P3 sullo stadio 11
# (run-p3-kut.sh, p3_contesa.flat). Stessi principi dei verdetti KUT e WSL:
#   PASS (0)          il programma KUT ha passato tutti i controlli (SUMMARY senza errori, codice QEMU 1 =
#                     isa-debug-exit con 0), i 3 round di contesa sono completi, il latch e' fermo, la sessione e'
#                     integra E la correzione e' stata ESERCITATA: hw.vmm.gla2gpa_restart_capped e' salito.
#   FAIL (1)          un difetto osservato: un controllo KUT fallito, un round mancante, il latch scattato, la QEMU
#                     uscita senza il codice di successo.
#   INCONCLUSIVO (5)  evidenza insufficiente (file mancanti, sessione non valida) OPPURE contatore fermo: la contesa
#                     non si e' prodotta e la correzione non e' stata esercitata (non e' ne' un PASS ne' un FAIL).
# Uso: p3-verdetto.py <cartella della sessione>
import json, os, re, sys

d = sys.argv[1]
fail, inc = [], []


def leggi(n):
	try:
		return open(os.path.join(d, n), errors='replace').read()
	except OSError:
		return None


man = leggi('manifest.txt')
if man is None:
	inc.append('manifest assente'); man = ''
if re.findall(r'^sessione: (APERTA|CHIUSA)$', man, re.M) != ['APERTA', 'CHIUSA']:
	inc.append('sessione non APERTA...CHIUSA nel manifest')
mp = re.findall(r'^piano (\S+) modo (\S+) ', man, re.M)
if mp != [('p3', '--esegui')]:
	inc.append('riga "piano p3 modo --esegui" assente o diversa: %r' % mp)
kp = re.findall(r'^kld prima: (.*)$', man, re.M); kd = re.findall(r'^kld dopo: (.*)$', man, re.M)
if len(kp) != 1 or kp != kd:
	inc.append('istanza del modulo non dimostrata la stessa prima e dopo (%s / %s)' % (kp, kd))
if re.findall(r'^stadio (\S+) firma oid (\S+)$', man, re.M) != [('stadio11', '11111')]:
	inc.append('il manifest non dice stadio11 con firma 11111')

# driver e QEMU
st = None
try:
	st = json.load(open(os.path.join(d, 'drv', 'stato.json')))
except (OSError, ValueError):
	inc.append('drv/stato.json assente o illeggibile')
if st is not None:
	if st.get('valida') is not True:
		inc.append('sessione del driver non valida: %r' % st.get('errori'))
	if st.get('timeout'):
		fail.append('la QEMU e\' arrivata al TIMEOUT del driver (test bloccato)')
	rc = st.get('qemu_rc')
	if rc is None:
		inc.append('codice d\'uscita della QEMU assente')
	elif rc != 1:
		fail.append('codice QEMU %r: il programma KUT non e\' uscito con successo (atteso 1 = isa-debug-exit 0)' % rc)

# seriale: controlli KUT e righe P3
se = leggi('drv/seriale.txt')
if se is None:
	inc.append('drv/seriale.txt assente'); se = ''
righe = [re.sub(r'^\d+\.\d+ ', '', l) for l in se.split('\n')]
ko = [l for l in righe if l.startswith('FAIL:')]
if ko:
	fail.append('controlli KUT falliti: %s' % ko[:3])
sk = [l for l in righe if l.startswith('SKIP:')]
if sk:
	inc.append('test saltato: %s' % sk[:1])
sm = [l for l in righe if l.startswith('SUMMARY:')]
if len(sm) != 1:
	inc.append('riga SUMMARY assente o doppia: %r' % sm)
elif 'unexpected failures' in sm[0]:
	fail.append('KUT: %s' % sm[0])
ok = [l for l in righe if l.startswith('PASS:')]
rnd = {}
for l in righe:
	m = re.match(r'^P3 round (\d+) cicli (\d+) durata (\d+) scritture (\d+)$', l)
	if m:
		rnd[int(m.group(1))] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
if sorted(rnd) != [1, 2, 3] and not sk:
	fail.append('round di contesa incompleti: %s (attesi 1, 2, 3)' % sorted(rnd))
if len(ok) != 7 and not sk and not ko:
	inc.append('controlli KUT passati: %d (attesi 7: PTE, VMXON, riferimento, 3 round, dopo)' % len(ok))

# sonde, latch, dmesg
so = leggi('sonde.txt')
sd = re.findall(r'^sonde (\S+) ([0-9a-f]{64}) etichetta (\S+)$', man, re.M)
if so is None or len(sd) != 1 or not re.search(r'^DTRACE_ATTIVO %s$' % re.escape(sd[0][2]), so, re.M):
	inc.append('traccia DTrace assente o non del programma dichiarato'); so = so or ''
if 'DTRACE_FINE' not in so:
	inc.append('traccia DTrace non chiusa regolarmente (manca DTRACE_FINE)')
if 'DTRACE_SCADUTO' in so:
	inc.append('traccia DTrace scaduta prima della fine della sessione')
ser = leggi('sonde-err.txt')
if ser is None:
	inc.append('sonde-err.txt assente')
elif ser.strip():
	inc.append('DTrace ha scritto su stderr: %r' % ser.strip()[:120])
latch = [l for l in so.split('\n') if re.match(r'^(FATAL_LATCH|FATAL_RITORNO|OPNDFATAL|VEPTUNEMUL) ', l)]
if latch:
	fail.append('sonde del latch scattate: %s' % latch[:2])
ct = leggi('contatori.txt')
cont = {}
for l in (ct or '').split('\n'):
	p = l.split()
	if len(p) == 3 and p[1].isdigit() and p[2].isdigit():
		cont[p[0]] = int(p[2]) - int(p[1])
if set(cont) != {'fatal_latches', 'nested_vept_mmio_unemulable', 'nested_operand_fatal'}:
	inc.append('contatori del latch assenti o malformati')
elif any(cont.values()):
	fail.append('contatori del latch cambiati: %s' % cont)
dm = leggi('dmesg-sessione.txt')
if dm is None:
	inc.append('dmesg della sessione assente'); dm = ''
if re.search(r'istruzione non completabile|panic|loop su VM_EXITCODE_NESTED', dm):
	fail.append('dmesg: %s' % re.findall(r'^.*(?:istruzione non completabile|panic|loop su VM_EXITCODE_NESTED).*$', dm, re.M)[:1])
if re.search(r'lock order reversal|WITNESS', dm):
	inc.append('WITNESS nel dmesg della sessione')

# la correzione ESERCITATA: hw.vmm.gla2gpa_restart_capped
cp = leggi('contatori-p3.txt')
m = re.match(r'^gla2gpa_restart_capped (\d+) (\d+)$', (cp or '').strip())
delta = None
if not m:
	inc.append('contatori-p3.txt assente o non numerico: %r' % (cp or '').strip()[:60])
else:
	delta = int(m.group(2)) - int(m.group(1))
	if delta < 0:
		inc.append('gla2gpa_restart_capped e\' DIMINUITO (%d): modulo ricaricato?' % delta)
	elif delta == 0:
		inc.append('gla2gpa_restart_capped fermo: la contesa non si e\' prodotta, la correzione NON e\' stata esercitata')

if fail:
	print('FAIL: ' + ' | '.join(fail) + (' (e INCONCLUSIVO: %s)' % ' | '.join(inc) if inc else '')); sys.exit(1)
if inc:
	print('INCONCLUSIVO: ' + ' | '.join(inc)); sys.exit(5)
print('PASS: provocazione di P3 sullo stadio 11: %d controlli KUT, 3 round completi (cicli %s), correzione esercitata '
      '%d volte (gla2gpa_restart_capped), latch fermo' % (len(ok), ','.join(str(rnd[k][0]) for k in (1, 2, 3)), delta))
sys.exit(0)
