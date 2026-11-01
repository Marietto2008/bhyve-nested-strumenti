#!/usr/local/bin/python3
# test-ombra.py -- Claude 31/10/2026, parere Opus C2. Collaudo con SEGNALI VERI delle trappole di om_ombra_accendi
# (opnd-manifest.sh): un /bin/sh figlio carica il produttore vero, simula il sysctl su un file (o_sysctl,
# o_sysctl_scrivi), accende l'ombra, segnala PRONTO e aspetta; il driver manda il segnale e controlla codice d'uscita e
# valore riportato a 0. Nessun sysctl vero, nessun sudo. Uso: test-ombra.py <cartella nuova> [produttore]
# 31/10/2026 (parere Opus sull'incidente): solo utente collaudo, sudo irraggiungibile
import os as _os, pwd as _pwd, shutil as _sh
_os.environ['PATH'] = '/bin:/usr/bin:/sbin:/usr/sbin:/mnt/linuxulator2/vm/wsl2/fbsd/collaudo-bin'
if _pwd.getpwuid(_os.getuid()).pw_name != 'collaudo':
	print('STOP: le suite girano solo come utente collaudo (sudo -u collaudo ...)'); raise SystemExit(2)
if _sh.which('sudo'):
	print('STOP: sudo raggiungibile dal collaudo'); raise SystemExit(2)
import os, signal, subprocess, sys, time
O = sys.argv[1]
P = sys.argv[2] if len(sys.argv) > 2 else '/mnt/linuxulator2/vm/wsl2/fbsd/opnd-manifest.sh'
os.makedirs(O)
nok = nko = 0
def esito(ok, m):
	global nok, nko
	nok += ok; nko += not ok
	print('  %s %s' % ('ok    ' if ok else 'ERRATO', m))
FIGLIO = r'''
. "%(P)s"
V=%(O)s/%(n)s.valore
o_sysctl() { cat "$V"; }
o_sysctl_scrivi() { [ -e %(O)s/%(n)s.scrittura_ignorata ] || printf '%%s\n' "$2" > "$V"; }
echo 0 > "$V"
om_ombra_accendi || exit 4
: > %(O)s/%(n)s.pronto
%(attesa)s
%(fine)s
'''
def caso(n, segnale, codice, attesa='sleep 30 & wait $!', fine='exit 0', ignora=False, ritardo=0.0, valore_atteso='0'):
	f = os.path.join(O, n + '.sh')
	open(f, 'w').write(FIGLIO % {'P': P, 'O': O, 'n': n, 'attesa': attesa, 'fine': fine})
	if ignora:
		open(os.path.join(O, n + '.scrittura_ignorata'), 'w').close()
	p = subprocess.Popen(['/bin/sh', f], stdout=open(os.path.join(O, n + '.out'), 'w'), stderr=subprocess.STDOUT)
	t0 = time.monotonic()
	while not os.path.exists(os.path.join(O, n + '.pronto')) and p.poll() is None and time.monotonic() - t0 < 10:
		time.sleep(0.05)
	if segnale:
		time.sleep(ritardo)
		p.send_signal(segnale)
	try:
		rc = p.wait(timeout=20)
	except subprocess.TimeoutExpired:
		p.kill(); rc = 'TIMEOUT'
	v = open(os.path.join(O, n + '.valore')).read().strip()
	esito(rc == codice and v == valore_atteso, '%-34s uscita %s (attesa %s), nested_shadow_vmcs %s (atteso %s)' %
	    (n, rc, codice, v, valore_atteso))
	return p
print('trappole dell\'ombra (opnd-manifest.sh, segnali veri)')
caso('term', signal.SIGTERM, 143)
caso('hup', signal.SIGHUP, 129)
caso('int', signal.SIGINT, 130)
caso('uscita_normale', None, 0, attesa='sleep 0.2')
caso('uscita_con_errore', None, 7, attesa='sleep 0.2', fine='exit 7')
caso('spegnimento_esplicito_poi_uscita', None, 0, attesa='sleep 0.2', fine='om_ombra_spegni; exit 0')
caso('accensione_non_riuscita', None, 4, ignora=True)
# la trappola gira solo a comando in primo piano CONCLUSO (sh): il runner aspetta il driver, che ha il suo timeout
t0 = time.monotonic()
caso('term_durante_comando_in_primo_piano', signal.SIGTERM, 143, attesa='sleep 2', ritardo=0.2)
esito(time.monotonic() - t0 >= 1.5, 'term_durante_comando_in_primo_piano: trappola eseguita a comando concluso (%.1f s)' %
    (time.monotonic() - t0))
print('SUMMARY: %d ok, %d errati' % (nok, nko))
sys.exit(1 if nko else 0)
