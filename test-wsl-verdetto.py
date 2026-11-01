#!/usr/local/bin/python3
# test-wsl-verdetto.py -- Claude 01/11/2026. Collaudo di wsl-verdetto.py, come utente collaudo. La sessione di base usa
# i file REALI di una corsa della serie del 20/10 (logs/serie-20261020-1619/corsa1: stats.txt, wsl-o.txt): un esemplare
# vero per ogni forma d'uscita. Ogni caso cambia una sola cosa e verifica esito E motivo.
# Uso: sudo -u collaudo python3 test-wsl-verdetto.py <cartella nuova in collaudi>
import os, pwd, shutil, subprocess, sys
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
VERO = W + '/logs/serie-20261020-1619/corsa1'
STATS = open(VERO + '/stats.txt').read()
WSLO = open(VERO + '/wsl-o.txt', errors='replace').read()
SH = 'a' * 64
MAN = ('sessione: APERTA\npiano wsl modo %(modo)s timeout 3600\nmodulo caricato: /x/vmm-restore.ko %(sh)s\nkld prima: id=56 loadcnt=71\n'
       'nested_shadow_vmcs %(ap)s\nvm0:12 prima: assente\navvio sessione: 1793500000\nsonde /x/sonde-wsl-v1.d %(sh)s etichetta sonde-wsl-v1\n'
       'kld dopo: id=56 loadcnt=71\ncontatori dopo: fatal_latches=0 nested_vept_mmio_unemulable=0 nested_operand_fatal=0\n'
       'vm0:12 dopo: creata 1793500010 (avvio sessione 1793500000) ID Length Name 1 32GB sysmem \nnested_shadow_vmcs alla chiusura 0\nsessione: CHIUSA\n')
def sessione(n, modo='--esegui', ap='0', man=None, sonde=None, shv=0, err='', cont=None, esito=None, stats=None, dmesg='', togli=()):
	d = os.path.join(O, n); os.makedirs(d)
	f = {
		'manifest.txt': man if man is not None else MAN % {'modo': modo, 'sh': SH, 'ap': ap},
		'sonde.txt': sonde if sonde is not None else 'DTRACE_ATTIVO sonde-wsl-v1\n' + ('FBT vmx_shvmcs_enter %d\n' % shv if shv else '') + 'DTRACE_FINE\n',
		'sonde-err.txt': err,
		'contatori.txt': cont if cont is not None else 'fatal_latches 0 0\nnested_vept_mmio_unemulable 0 0\nnested_operand_fatal 0 0\n',
		'esito.txt': esito if esito is not None else 'desktop 112\nwsl microsoft-standard-WSL2\nsha SHA-OK\nbhyve_rc 1 spento_da_windows 1 durata 420\nesito OK\n',
		'stats.txt': stats if stats is not None else STATS,
		'wsl-o.txt': WSLO,
		'dmesg-sessione.txt': dmesg,
	}
	for k, v in f.items():
		if k not in togli:
			open(os.path.join(d, k), 'w').write(v)
	return d
nok = nko = 0
def caso(n, atteso, motivo, **k):
	global nok, nko
	d = sessione(n, **k)
	p = subprocess.run(['python3', W + '/wsl-verdetto.py', d], capture_output=True, text=True)
	ok = p.returncode == atteso and motivo in p.stdout
	nok += ok; nko += not ok
	print('  %s %-34s uscita %d (attesa %d): %s' % ('ok    ' if ok else 'ERRATO', n, p.returncode, atteso, p.stdout.strip()[:150]))
print('esemplare reale: %s (stats.txt %d righe, wsl-o.txt %r)' % (VERO, STATS.count('\n'), WSLO.split('\n')[0]))
caso('pass', 0, 'PASS: corsa wsl --esegui')
caso('pass_ombra', 0, 'ombra 50000 ingressi', modo='--esegui-ombra', ap='1', shv=50000)
# sonde v2 (01/11, dopo la corsa 2): finestre "F <epoca>", motivi "L2 <n> <conteggio>" e "RIF <n> <conteggio>"; la forma
# e' quella REALE stampata da sonde-wsl-v2.d (prova di 12 s del 01/11 sul modulo caricato), coi conteggi aggiunti
V2 = ('DTRACE_ATTIVO sonde-wsl-v2\nF 1793499833\nL2 48 120345\nL2 1 98012\nRIF 48 3021\nRIF 1 97950\n'
      'F 1793499843\nL2 48 5\nDTRACE_FINE\n')
caso('pass_v2', 0, 'PASS: corsa wsl --esegui', man=(MAN % {'modo': '--esegui', 'sh': SH, 'ap': '0'}).replace('sonde-wsl-v1', 'sonde-wsl-v2'), sonde=V2)
caso('v2_etichetta_v1', 5, 'non del programma dichiarato', sonde=V2)
# sonde v3 (parere #172): righe C/CV/CS/D/IA/IF/IO/RIF/MAPV/MAPP; la v3 non deve confondere il verdetto
V3 = ('DTRACE_ATTIVO sonde-wsl-v3\nF 1793499833\nC 101 9800\nCV 101 0 236 120\nCS 101 1 0 9800\nD 101 0 1 0 236 209 40\n'
      'IA 101 0 1 40\nIF 101 0 39\nRIF 101 1 300\nF 1793499843\nMAPV 101 0 80\nMAPP 101 fffff80012345000 9900\nDTRACE_FINE\n')
caso('pass_v3', 0, 'PASS: corsa wsl --esegui', man=(MAN % {'modo': '--esegui', 'sh': SH, 'ap': '0'}).replace('sonde-wsl-v1', 'sonde-wsl-v3'), sonde=V3)
caso('v3_latch', 1, 'sonde del latch', man=(MAN % {'modo': '--esegui', 'sh': SH, 'ap': '0'}).replace('sonde-wsl-v1', 'sonde-wsl-v3'), sonde=V3.replace('DTRACE_FINE', 'OPNDFATAL vcpu=0 stadio=4 err=14 rip=0x1 gla=0x2\nDTRACE_FINE'))
caso('v2_latch', 1, 'sonde del latch', man=(MAN % {'modo': '--esegui', 'sh': SH, 'ap': '0'}).replace('sonde-wsl-v1', 'sonde-wsl-v2'), sonde=V2.replace('DTRACE_FINE', 'FATAL_LATCH vcpu=1 errno=14 stadio=4 rip=0x1 gpa=0 gla=0x2\nDTRACE_FINE'))
# FAIL: difetti osservati
caso('latch_sonda', 1, 'sonde del latch', sonde='DTRACE_ATTIVO sonde-wsl-v1\nFATAL_LATCH vcpu=1 errno=14 stadio=4 rip=0x1 gpa=0 gla=0x2\nDTRACE_FINE\n')
caso('latch_contatori', 1, 'contatori del latch cambiati', cont='fatal_latches 0 1\nnested_vept_mmio_unemulable 0 0\nnested_operand_fatal 0 1\n')
caso('no_desktop', 1, 'corsa: NO-DESKTOP', esito='desktop -1\nbhyve_rc 1 spento_da_windows 0 durata 900\nesito NO-DESKTOP\n')
caso('bhyve_uscito', 1, 'corsa: BHYVE-USCITO', esito='desktop -1\nbhyve_rc 4 spento_da_windows 0 durata 30\nesito BHYVE-USCITO\n')
caso('wsl_muta', 1, 'WSL2 non ha risposto', esito='desktop 110\nwsl \nsha \nbhyve_rc 1 spento_da_windows 1 durata 700\nesito OK\n')
caso('sha_diverso', 1, 'prova SHA-256', esito='desktop 110\nwsl microsoft-standard-WSL2\nsha SHA-DIVERSO\nbhyve_rc 1 spento_da_windows 1 durata 400\nesito OK\n')
caso('no_spegnimento', 1, 'NO-SPEGNIMENTO', esito='desktop 110\nwsl microsoft-standard-WSL2\nsha SHA-OK\nbhyve_rc 137 spento_da_windows 0 durata 900\nesito NO-SPEGNIMENTO\n')
caso('bhyve_rc_triplo', 1, 'spegnimento non pulito: bhyve rc 3', esito='desktop 110\nwsl microsoft-standard-WSL2\nsha SHA-OK\nbhyve_rc 3 spento_da_windows 1 durata 400\nesito OK\n')
caso('vmfail', 1, 'VMfail restituiti', stats=STATS.replace("vcpu1 VMfailValid restituiti all'L1           \t0", "vcpu1 VMfailValid restituiti all'L1           \t3"))
caso('vmcs12_corrotto', 1, 'VMCS12 corrotti', stats=STATS.replace("vcpu0 VMCS12: regione corrotta o non mappabile\t0", "vcpu0 VMCS12: regione corrotta o non mappabile\t1"))
caso('dmesg_latch', 1, 'latch nel dmesg', dmesg='vmm: vm0:12 vcpu 1: istruzione non completabile (stadio 4, errno 14)\n')
caso('ombra_guasto', 1, 'guasto dell\'ombra', modo='--esegui-ombra', ap='1', shv=10, dmesg='nested shadow VMCS: vcpu0 errore 7, VM fermata\n')
# INCONCLUSIVO: evidenza insufficiente
caso('witness', 5, 'WITNESS', dmesg='lock order reversal:\n')
caso('etichetta_assente', 5, 'non del programma dichiarato', sonde='DTRACE_ATTIVO\nDTRACE_FINE\n')
caso('etichetta_altra', 5, 'non del programma dichiarato', sonde='DTRACE_ATTIVO sonde-opnd-v2\nDTRACE_FINE\n')
caso('senza_fine', 5, 'manca DTRACE_FINE', sonde='DTRACE_ATTIVO sonde-wsl-v1\n')
caso('scaduta', 5, 'scaduta', sonde='DTRACE_ATTIVO sonde-wsl-v1\nDTRACE_SCADUTO\nDTRACE_FINE\n')
caso('stderr_dtrace', 5, 'stderr', err='dtrace: 1 drop on CPU 3\n')
caso('kld_ricaricato', 5, 'istanza del modulo', man=(MAN % {'modo': '--esegui', 'sh': SH, 'ap': '0'}).replace('kld dopo: id=56 loadcnt=71', 'kld dopo: id=56 loadcnt=72'))
caso('sessione_incompleta', 5, 'APERTA...CHIUSA', man=(MAN % {'modo': '--esegui', 'sh': SH, 'ap': '0'}).replace('sessione: CHIUSA\n', ''))
caso('modo_ignoto', 5, 'piano wsl modo', man=(MAN % {'modo': '--esegui-d', 'sh': SH, 'ap': '0'}))
caso('ombra_senza_ingressi', 5, 'vmx_shvmcs_enter', modo='--esegui-ombra', ap='1', shv=0)
caso('ombra_senza_modo', 5, 'senza --esegui-ombra', shv=99)
caso('ombra_apertura_0', 5, 'all\'apertura 0', modo='--esegui-ombra', ap='0', shv=99)
caso('stats_assenti', 5, 'contatori VMfail/VMCS12 assenti', stats='')
caso('manifest_assente', 5, 'manifest assente', togli=('manifest.txt',))
caso('esito_assente', 5, 'esito.txt assente', togli=('esito.txt',))
caso('contatori_assenti', 5, 'contatori del latch assenti', togli=('contatori.txt',))
print('SUMMARY: %d ok, %d errati' % (nok, nko))
sys.exit(1 if nko else 0)
