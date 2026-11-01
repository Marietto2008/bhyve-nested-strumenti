#!/usr/local/bin/python3
# wsl-verdetto.py -- Claude 01/11/2026. Verdetto di UNA corsa della campagna Hyper-V/WSL2 sullo stadio 10
# (run-wsl-corsa.sh), dalla cartella della sessione. Stessi principi del verdetto KUT (opnd-verdetto.py):
#   PASS (0)          Windows al desktop, WSL2 risponde (uname con microsoft-standard-WSL2), prova SHA-256 identica dopo
#                     lo svuotamento delle cache, 0 VMfail e 0 VMCS12 corrotti per ogni vCPU, spegnimento pulito da
#                     Windows (bhyve rc 1 = poweroff), latch fermo (delta 0/0/0, nessuna sonda del latch), modo e ombra
#                     coerenti, la stessa istanza del modulo prima e dopo.
#   FAIL (1)          un difetto osservato nell'ospite o in L0.
#   INCONCLUSIVO (5)  l'evidenza non basta per dire PASS o FAIL (file mancanti, traccia DTrace incompleta, WITNESS...).
# Uso: wsl-verdetto.py <cartella della sessione>
import os, re, sys

d = sys.argv[1]
fail, inc = [], []
def leggi(n):
	try:
		return open(os.path.join(d, n), errors='replace').read()
	except OSError:
		return None

# --- manifest: sessione, piano e modo, istanza del modulo, ombra
man = leggi('manifest.txt')
if man is None:
	inc.append('manifest assente'); man = ''
if re.findall(r'^sessione: (APERTA|CHIUSA)$', man, re.M) != ['APERTA', 'CHIUSA']:
	inc.append('sessione non APERTA...CHIUSA nel manifest')
mp = re.findall(r'^piano (\S+) modo (\S+) ', man, re.M)
modo = mp[0][1] if len(mp) == 1 and mp[0][0] == 'wsl' else None
if modo not in ('--esegui', '--esegui-ombra'):
	inc.append('riga "piano wsl modo ..." assente, doppia o con modo non ammesso: %r' % mp)
kp = re.findall(r'^kld prima: (.*)$', man, re.M); kd = re.findall(r'^kld dopo: (.*)$', man, re.M)
if len(kp) != 1 or kp != kd:
	inc.append('istanza del modulo non dimostrata la stessa prima e dopo (%s / %s)' % (kp, kd))
ap = re.findall(r'^nested_shadow_vmcs (\S+)$', man, re.M); ch = re.findall(r'^nested_shadow_vmcs alla chiusura (\S+)$', man, re.M)

# --- sonde
so = leggi('sonde.txt')
sd = re.findall(r'^sonde (\S+) ([0-9a-f]{64}) etichetta (\S+)$', man, re.M)
if so is None or len(sd) != 1 or not re.search(r'^DTRACE_ATTIVO %s$' % re.escape(sd[0][2]), so, re.M):
	inc.append('traccia DTrace assente o non del programma dichiarato'); so = so or ''
if 'DTRACE_FINE' not in so:
	inc.append('traccia DTrace non chiusa regolarmente (manca DTRACE_FINE)')
if 'DTRACE_SCADUTO' in so:
	inc.append('traccia DTrace scaduta prima della fine della corsa')
se = leggi('sonde-err.txt')
if se is None:
	inc.append('sonde-err.txt assente')
elif se.strip():
	inc.append('DTrace ha scritto su stderr: %r' % se.strip()[:120])
if 'drop' in so.lower() or 'drop' in (se or '').lower():
	inc.append('DTrace segnala perdite')
latch = [l for l in so.split('\n') if re.match(r'^(FATAL_LATCH|FATAL_RITORNO|OPNDFATAL|VEPTUNEMUL) ', l)]
if latch:
	fail.append('sonde del latch scattate: %s' % latch[:2])
fbt = dict((m.group(1), int(m.group(2))) for m in re.finditer(r'^FBT (\S+) (\d+)$', so, re.M))
shv = fbt.get('vmx_shvmcs_enter', 0)

# --- contatori del latch
ct = leggi('contatori.txt')
cont = {}
for l in (ct or '').split('\n'):
	p = l.split()
	if len(p) == 3 and p[1].isdigit() and p[2].isdigit():
		cont[p[0]] = int(p[2]) - int(p[1])
if set(cont) != {'fatal_latches', 'nested_vept_mmio_unemulable', 'nested_operand_fatal'}:
	inc.append('contatori del latch assenti o malformati')
elif any(cont.values()):
	fail.append('contatori del latch cambiati durante la corsa: %s' % cont)

# --- l'ospite: esito, desktop, WSL, SHA-256, spegnimento
es = leggi('esito.txt')
if es is None:
	inc.append('esito.txt assente: nessuna conclusione sull\'ospite')	# un file mancante non e' un difetto osservato
else:
	def campo(k):
		m = re.findall(r'^%s (.*)$' % k, es, re.M)
		return m[-1].strip() if m else None
	e = campo('esito')
	if e is None:
		inc.append('esito della corsa assente')
	elif e != 'OK':
		fail.append('corsa: %s' % e)
	desk = campo('desktop')
	if desk is None or not re.match(r'^-?\d+$', desk) or int(desk) < 0:
		fail.append('Windows non e\' arrivato al desktop (%r)' % desk)
	if campo('wsl') != 'microsoft-standard-WSL2':
		fail.append('WSL2 non ha risposto (uname senza microsoft-standard-WSL2: %r)' % campo('wsl'))
	if campo('sha') != 'SHA-OK':
		fail.append('prova SHA-256 in WSL non riuscita: %r' % campo('sha'))
	br = re.findall(r'^bhyve_rc (\d+) spento_da_windows (\d) ', es, re.M)
	if not br:
		inc.append('codice d\'uscita di bhyve assente')
	elif br[-1] != ('1', '1'):
		fail.append('spegnimento non pulito: bhyve rc %s, spento da Windows %s (atteso rc 1 = poweroff)' % br[-1])

# --- contatori nested per vCPU (bhyvectl --get-stats)
st = leggi('stats.txt') or ''
vf = [(m.group(1), int(m.group(2))) for m in re.finditer(r'^(vcpu\d+ VMfail\w+) restituiti all\'L1\s+(\d+)$', st, re.M)]
cor = [(m.group(1), int(m.group(2))) for m in re.finditer(r'^(vcpu\d+) VMCS12: regione corrotta o non mappabile\s+(\d+)$', st, re.M)]
if len(vf) < 4 or len(cor) < 2:
	inc.append('contatori VMfail/VMCS12 assenti per qualche vCPU (%d VMfail, %d VMCS12)' % (len(vf), len(cor)))
if any(v for _, v in vf):
	fail.append('VMfail restituiti all\'L1: %s' % [x for x in vf if x[1]])
if any(v for _, v in cor):
	fail.append('VMCS12 corrotti o non mappabili: %s' % [x for x in cor if x[1]])

# --- dmesg della corsa
dm = leggi('dmesg-sessione.txt')
if dm is None:
	inc.append('dmesg della sessione assente'); dm = ''
if re.search(r'istruzione non completabile', dm):
	fail.append('latch nel dmesg: %s' % re.findall(r'^.*istruzione non completabile.*$', dm, re.M)[:1])
if re.search(r'lock order reversal|WITNESS', dm):
	inc.append('WITNESS nel dmesg della corsa')
spento = re.findall(r'^nested shadow VMCS: .*resta spento$', dm, re.M)
guasto = re.findall(r'^nested shadow VMCS: vcpu\d+ errore .*$', dm, re.M)

# --- ombra e modo (come il verdetto KUT v8)
if len(ap) != 1 or len(ch) != 1:
	inc.append('nested_shadow_vmcs all\'apertura %r, alla chiusura %r (attese una riga ciascuna)' % (ap, ch))
elif modo == '--esegui-ombra':
	if ap[0] != '1': inc.append('corsa con l\'ombra ma nested_shadow_vmcs all\'apertura %s' % ap[0])
	if ch[0] != '0': inc.append('nested_shadow_vmcs alla chiusura %s (atteso 0)' % ch[0])
	if shv <= 0: inc.append('nessun ingresso in vmx_shvmcs_enter: l\'ombra non e\' stata usata')
	if spento: inc.append('il modulo ha lasciato l\'ombra spenta: %s' % spento[:1])
	if guasto: fail.append('guasto dell\'ombra in L0: %s' % guasto[:1])
elif modo == '--esegui':
	if ap[0] != '0' or ch[0] != '0': inc.append('nested_shadow_vmcs %s/%s senza ombra (attesi 0/0)' % (ap[0], ch[0]))
	if shv != 0: inc.append('ombra attiva (%d ingressi) senza --esegui-ombra' % shv)
	if spento or guasto: inc.append('messaggi dell\'ombra senza --esegui-ombra')

if fail:
	print('FAIL: ' + ' | '.join(fail) + (' (e INCONCLUSIVO: %s)' % ' | '.join(inc) if inc else '')); sys.exit(1)
if inc:
	print('INCONCLUSIVO: ' + ' | '.join(inc)); sys.exit(5)
print('PASS: corsa wsl %s, desktop %s s, WSL2 e SHA-256 ok, 0 VMfail, spegnimento pulito, latch fermo%s' %
      (modo, desk, ', ombra %d ingressi' % shv if modo == '--esegui-ombra' else ''))
sys.exit(0)
