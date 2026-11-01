#!/bin/sh
# eptp-equiv.sh -- Claude 31/10/2026, parere #163 §5.6. Il controllo dell'EPTP del VM entry prima (espressione inline
# di nested_check_vmentry, stadio 6) e dopo (nested_eptp_ok, stadio 7) deve coincidere su tutto il dominio dei campi
# che contano: i 12 bit bassi (tipo, walk, A/D, 11:7), bit alti scelti, indirizzi, capacita' 6/8/14/21, MAXPHYADDR.
# Verifica anche che il VM entry dello stadio 7 chiami nested_eptp_ok al posto dell'espressione.
# Uso: eptp-equiv.sh <vmx_nested.c stadio 6> <vmx_nested.c stadio 7> <cartella di uscita>
B=/mnt/linuxulator2/vm/wsl2/linux/banco-opnd
V=${1:?stadio 6}; N=${2:?stadio 7}; O=${3:?uscita}
mkdir -p "$O" || exit 2
python3 - "$V" "$N" "$O/eptp.c" "$B/eptp-equiv.c.modello" <<'FINE_PY_EPTPGEN'
import sys, re, subprocess
vecchio = open(sys.argv[1]).read()
m = re.search(r"uint64_t mt = e & 7;\n\n\t\tif \((.*?)\)\n\t\t\treturn \(VMXERR_ENTRY_INVALID_CONTROL_FIELD\);", vecchio, re.S)
if not m:
    sys.exit('espressione del VM entry non trovata nello stadio 6')
nuovo = open(sys.argv[2]).read()
if nuovo.count('!nested_eptp_ok(cap, vmcs12_read_field(c, VMCS_EPTP)))') != 1:
    sys.exit('VM entry dello stadio 7: chiamata a nested_eptp_ok assente')
f = subprocess.run(['python3', '/mnt/linuxulator2/vm/wsl2/linux/banco-opnd/estrai.py', sys.argv[2], 'nested_eptp_ok'],
    capture_output=True, text=True)
if f.returncode != 0:
    sys.exit('nested_eptp_ok non estratta')
t = open(sys.argv[4]).read()
t = t.replace('@@VECCHIO@@', ' '.join(m.group(1).split())).replace('@@NUOVO@@', f.stdout)
open(sys.argv[3], 'w').write(t)
FINE_PY_EPTPGEN
[ -s "$O/eptp.c" ] || exit 2
cc -std=gnu11 -Wall -o "$O/eptp" "$O/eptp.c" > "$O/cc.txt" 2>&1 || { cat "$O/cc.txt"; exit 2; }
"$O/eptp" > "$O/esito.txt" 2>&1; r=$?
cat "$O/esito.txt"
exit $r
