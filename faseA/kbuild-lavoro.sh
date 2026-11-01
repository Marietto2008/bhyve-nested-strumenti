#!/bin/bash
# kbuild-lavoro.sh -- Claude 27/10/2026, parere #86 §2: QUANTITA' e IDENTITA' del
# lavoro della compilazione appena fatta da kbuild4.sh, per dimostrare che i
# quattro bracci dell'ABBA hanno compilato la STESSA cosa. Gira DOPO la
# compilazione (fuori dal tempo misurato), solo letture, nessuna modifica:
#   AZIONI_CC / AZIONI_TOT  righe "  CC ..." e tutte le azioni di kbuild nel log
#   CONFIG                  sha256 del .config (defconfig)
#   MAKEFILE                sha256 del Makefile principale (versione dei sorgenti)
#   SORGENTI / SORGENTI_KB  file .c/.h/.S NON piu' recenti del Makefile (quelli
#                           del tarball: i generati dalla compilazione sono piu'
#                           recenti) e loro dimensione totale
#   GCC / MAKE / NPROC      toolchain e CPU visti da WSL
L=/mnt/c/claude/faseA
exec > "$L/kbuild-lavoro.txt" 2>&1
cd /root/linux-6.6.58 || { echo "ERRORE cartella"; echo LAVORO-FINE; exit 1; }
echo "AZIONI_CC=$(grep -cE '^  CC ' /root/kbuild-out.log)"
echo "AZIONI_TOT=$(grep -cE '^  [A-Z_]+ ' /root/kbuild-out.log)"
echo "CONFIG=$(sha256sum .config | cut -c1-64)"
echo "MAKEFILE=$(sha256sum Makefile | cut -c1-64)"
echo "SORGENTI=$(find . -type f \( -name '*.c' -o -name '*.h' -o -name '*.S' \) ! -newer Makefile | wc -l)"
echo "SORGENTI_KB=$(find . -type f \( -name '*.c' -o -name '*.h' -o -name '*.S' \) ! -newer Makefile -print0 | du -k --files0-from=- | awk '{s += $1} END {print s}')"
echo "GCC=$(gcc -dumpfullversion)"
echo "MAKE=$(make --version | head -1 | tr ' ' '_')"
echo "NPROC=$(nproc)"
echo LAVORO-FINE
