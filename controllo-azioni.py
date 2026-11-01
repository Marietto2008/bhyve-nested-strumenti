#!/usr/bin/env python3
# controllo-azioni.py -- Claude 01/11/2026, parere Opus «letture chiuse» par. 3.1-3.3. Controllo STATICO, sola lettura,
# v3: lavora per OCCORRENZA di sudo, comando semplice per comando semplice, non per riga.
#  - righe di continuazione (`\` a fine riga) unite; commenti tolti rispettando le virgolette;
#  - si tolgono le LETTURE ammesse, scritte per intero e seguite solo da un terminatore di comando, e le STRINGHE di
#    messaggio ammesse (testo esatto); ogni `sudo` che resta e' un'AZIONE;
#  - un'azione e' guardata solo se il comando che la precede immediatamente e' `guardia_azione [VAR]` con `&&`,
#    oppure `guardia_azione [VAR] || <ferma ...|exit N|return N>;` subito prima; un comando con DUE sudo e' un difetto;
#  - un INERTE si riconosce dalla forma esatta delle prime tre righe, non dal commento.
# Uso: controllo-azioni.py [elenco approvati] [file sequenza] [file in piu' per il punto 3] [cartella in piu' per il 4]
import glob, os, re, sys

W = '/mnt/linuxulator2/vm/wsl2/linux'
L = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else W + '/APPROVATI-sequenza.sha256'
SEQS = [sys.argv[2]] if len(sys.argv) > 2 and sys.argv[2] else [W + '/sequenza-kut.sh', W + '/sequenza-wsl.sh', W + '/sequenza-p3.sh']	# 01/11: anche la campagna WSL e il test di P3
EXTRA3 = [sys.argv[3]] if len(sys.argv) > 3 and sys.argv[3] else []
EXTRA4 = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None

# LETTURE ammesse (elenco chiuso, parere Opus par. 4): testo esatto del comando, redirezioni comprese
LETTURE = [
	'sudo -n /usr/bin/fstat "/dev/vmm/$1" 2>/dev/null',
	'sudo -n /usr/sbin/bhyvectl --vm="$1" --get-memseg 2>&1',
	'sudo -n /usr/sbin/bhyvectl --vm=vm2 --get-memseg 2>&1',
	'sudo -n /usr/sbin/bhyvectl --vm="$OM_VM" --get-memseg 2>&1',
	'sudo -n /usr/sbin/bhyvectl --vm="$1" --cpu="$2" --get-stats 2>&1',
	"sudo -n /usr/sbin/dtrace -l -n 'vmm:::fatal-latch' -n 'vmm:::fatal-ritorno' -n 'vmm:vmx:nested:veptunemul' "
	"-n 'vmm:vmx:nested:opndfatal' -n ':::fatal-latch' -n ':::fatal-ritorno' -n ':::veptunemul' -n ':::opndfatal' 2>/dev/null",
	'sudo -n /usr/sbin/dtrace -e -s $FBTR 1 >/dev/null 2>&1',
	'sudo -n /usr/sbin/dtrace -s /mnt/linuxulator2/vm/wsl2/linux/kld-loadcnt.d vmm-restore.ko 2>&1',
	'sudo -n /usr/sbin/dtrace -s $OM_KLD_D vmm-restore.ko 2>&1',
	'sudo -n /usr/bin/true 2>/dev/null',
]
# MESSAGGI: stringhe che nominano sudo senza invocarlo (testo esatto, virgolette comprese)
MESSAGGI = [
	'"comando: sudo -n $DRVCMD"',
	'"ATTENZIONE: sudo $om_sp o $om_nome $om_fp0 ancora vivi dopo SIGKILL"',
	'"sudo -n non disponibile"',
	'"sudo: $(/usr/local/bin/sudo -V | /usr/bin/head -1); sha $(/sbin/sha256 -q /usr/local/bin/sudo); '
	'pacchetto $(/usr/sbin/pkg which -q /usr/local/bin/sudo 2>/dev/null)"',
]
TERMINE = re.compile(r'\s*($|[;|&)}`"])')
# v4 (parere Opus «wrapper di root» par. 4.1): anche col percorso completo (/usr/local/bin/sudo), e doas; su solo in
# posizione di comando (la parola compare nei messaggi in italiano). sudoers resta escluso dal lookahead.
SUDO = re.compile(r'(?<![\w.-])(?:sudo|doas)(?![\w.-])')
SU = re.compile(r'^(?:\w+=\S*\s+)*(?:exec\s+|env\s+(?:-\S+\s+)*)?(?:/usr/bin/)?su(?:\s|$)')
def elevatori(c):
	return len(SUDO.findall(c)) + (1 if SU.match(c) else 0)
GUARDIA = re.compile(r'^guardia_azione( [A-Z_]+)?$')
FERMA = re.compile(r'^(ferma\b.*|exit( [0-9]+)?|return( [0-9]+)?)$')
INERTE3 = re.compile(r'^echo "INERTE: [^"]*" >&2; exit 4$')

def righe_logiche(testo):
	"""(numero della prima riga fisica, testo) con le continuazioni unite"""
	out, buf, n0 = [], None, 0
	for i, r in enumerate(testo.split('\n'), 1):
		if buf is None:
			n0 = i
		if r.endswith('\\'):
			buf = (buf + ' ' if buf is not None else '') + (r[:-1].rstrip() if buf is None else r[:-1].strip())
			continue
		out.append((n0, (buf + ' ' + r.strip()) if buf is not None else r))
		buf = None
	if buf is not None:
		out.append((n0, buf))
	return out

def senza_commento(r):
	q = None
	for i, c in enumerate(r):
		if q:
			if c == q and (q == "'" or r[i - 1] != '\\'):
				q = None
		elif c in '\'"':
			q = c
		elif c == '#' and (i == 0 or r[i - 1] in ' \t'):
			return r[:i]
	return r

def togli_letture(r):
	for l in LETTURE:
		i = r.find(l)
		while i >= 0:
			if TERMINE.match(r, i + len(l)):
				r = r[:i] + ' ' + r[i + len(l):]
				i = r.find(l)
			else:
				i = r.find(l, i + 1)
	for m in MESSAGGI:
		r = r.replace(m, '""')
	return r

def comandi(r):
	"""[(separatore che precede, comando)]"""
	r = r.replace('>&', '\x03').replace('&>', '\x04')
	pezzi = re.split(r'(&&|\|\||\$\(|[;&|(){}`])', r)
	out, sep = [], ''
	for p in pezzi:
		if p in ('&&', '||', '$(', ';', '&', '|', '(', ')', '{', '}', '`'):
			sep = p
			continue
		c = p.strip().replace('\x03', '>&').replace('\x04', '&>')
		if c:
			out.append((sep, c))
			sep = ''
	return out

def non_guardate(f):
	try:
		t = open(f, errors='replace').read()
	except OSError as e:
		return [(0, 'illeggibile: %s' % e)]
	dif = []
	for n, r in righe_logiche(t):
		r = togli_letture(senza_commento(r))
		cc = comandi(r)
		if not any(elevatori(c) for _, c in cc):
			continue
		for k, (sep, c) in enumerate(cc):
			ns = elevatori(c)
			if ns == 0:
				continue
			if ns > 1:
				dif.append((n, 'due elevatori (sudo/doas/su) nello stesso comando: ' + c[:100]))
				continue
			g = (k >= 1 and sep == '&&' and GUARDIA.match(cc[k - 1][1])) or \
			    (k >= 2 and sep == ';' and FERMA.match(cc[k - 1][1]) and cc[k - 1][0] == '||' and GUARDIA.match(cc[k - 2][1]))
			if not g:
				dif.append((n, "sudo che non e' una lettura dell'elenco e non e' preceduto da guardia_azione: " + c[:100]))
	return dif

def inerte(f):
	try:
		rr = open(f, errors='replace').read().split('\n')
	except OSError:
		return False
	return len(rr) >= 3 and rr[0].startswith('#!') and rr[1].startswith('# INERTE (') and bool(INERTE3.match(rr[2]))

def carica_preambolo(f):
	try:
		rr = open(f, errors='replace').read().split('\n')[:15]
	except OSError:
		return False
	return any(r.startswith('. /mnt/linuxulator2/vm/wsl2/linux/collaudo-preambolo.sh') for r in rr)

nd = 0
def difetto(s):
	global nd
	nd += 1
	print('  DIFETTO ' + s)

print('controllo-azioni v3 (per occorrenza)')
print('1. strumenti approvati (%s)' % L)
try:
	elenco = [r.split() for r in open(L).read().split('\n') if r.strip() and not r.startswith('#')]
except OSError:
	print('  elenco assente'); sys.exit(1)
approvati = {x[1] for x in elenco if len(x) == 2}
for f in sorted(x for x in approvati if x.endswith('.sh')):
	d = non_guardate(f)
	for n, s in d:
		difetto('%s:%d: %s' % (f, n, s))
	try:
		t = open(f, errors='replace').read()
	except OSError:
		continue			# gia' riportato come DIFETTO da non_guardate
	ng = sum(1 for _, r in righe_logiche(t) if 'guardia_azione' in senza_commento(r) and SUDO.search(togli_letture(senza_commento(r))))
	if ng and f != W + '/caldo/guardia.sh' and not re.search(r'^\. /mnt/linuxulator2/vm/wsl2/linux/caldo/guardia\.sh', t, re.M):
		difetto('%s: usa guardia_azione ma non carica guardia.sh' % f)
	print('  %s: %d righe con azioni guardate, %d difetti' % (f.replace(W + '/', ''), ng, len(d)))

for SEQ in SEQS:
 print('2. sequenza (%s)' % SEQ)
 s = open(SEQ, errors='replace').read()
 for n, r in righe_logiche(s):
 	r = senza_commento(r)
 	if SUDO.search(r):
 		difetto('%s:%d: la sequenza usa sudo' % (SEQ, n))
 	if re.search(r'smoke-modulo\.sh|modulo-caldo\.sh|run-opnd-kut\.sh|run-wsl-corsa\.sh|run-p3-kut\.sh|vm0-12-wsl|vmm-residuo\.sh|kut-drive|bhyvectl|kldload|devctl', r) and \
 	   not re.match(r'^T_SMOKE=\$C/smoke-modulo\.sh; T_CALDO=\$C/modulo-caldo\.sh; T_RUNNER=\$W/run-(opnd-kut|wsl-corsa|p3-kut)\.sh; T_RESIDUO=\$C/vmm-residuo\.sh$', r.strip()):
 		difetto('%s:%d: nomina strumenti fuori dalla riga T_*: %s' % (SEQ, n, r.strip()[:100]))
 	if re.search(r'\$T_(SMOKE|CALDO|RUNNER|RESIDUO)', r) and not re.match(r'^t_(smoke|caldo|runner|residuo)\(\) +\{ sh "\$T_[A-Z]+" "\$@"; \}$', r.strip()) \
 	   and 'T_CALDO=$T_SMOKE' not in r:
 		difetto('%s:%d: usa $T_* fuori dalle funzioni t_*: %s' % (SEQ, n, r.strip()[:100]))

print('3. vmm-gettone nominato da script del workspace (vietato fuori da gettone/)')
cand = glob.glob(W + '/*.sh') + glob.glob(W + '/*.py') + glob.glob(W + '/caldo/*.sh') + glob.glob(W + '/caldo/*.py') + EXTRA3
for f in sorted(set(cand)):
	if f in (W + '/controllo-azioni.py', W + '/controllo-azioni.sh'):
		continue
	try:
		if 'vmm-gettone' in open(f, errors='replace').read():
			difetto('vmm-gettone nominato in: %s' % f)
	except OSError:
		pass

print('4. altri script con sudo non guardati (NON conformi: vanno resi inerti)')
altri = glob.glob(W + '/*.sh') + glob.glob(W + '/caldo/*.sh') + (glob.glob(EXTRA4 + '/*.sh') if EXTRA4 else [])
nc = 0
for f in sorted(set(altri)):
	if f in approvati or f == W + '/controllo-azioni.sh' or f == W + '/collaudo-preambolo.sh':
		continue
	if inerte(f) or carica_preambolo(f):
		continue
	if non_guardate(f):
		nc += 1
		print('  non conforme: %s' % f.replace(W + '/', ''))
print('  totale non conformi e non inerti: %d' % nc)
print('SUMMARY: %d difetti' % nd)
sys.exit(1 if nd else 0)
