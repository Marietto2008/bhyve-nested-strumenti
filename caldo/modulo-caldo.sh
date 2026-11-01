#!/bin/sh
# modulo-caldo.sh -- Claude 29/10/2026. Cambio A CALDO di vmm-restore.ko protetto da `devctl freeze`.
# Sostituisce modulo-h1fix.sh (non idoneo, checkpoint #115 §5). Logica in mc-logica.sh, accesso all'host in
# mc-sistema.sh, collaudo su sistema simulato in test-modulo-caldo.sh.
#
#   sh modulo-caldo.sh --prova  originale originale|r110     sola lettura, mostra la sequenza
#   sh modulo-caldo.sh --esegui originale originale          prova del MECCANISMO (consenso)
#   sh modulo-caldo.sh --esegui originale r110               (consenso)
#   sh modulo-caldo.sh --esegui r110 originale               ritorno
# Uscita: 0 ok | 4 STOP, nulla cambiato | 5 fallito ma tornato all'originale verificato | 6 OPERATORE.
set -u
# 31/10/2026, incidente del collaudo di sequenza-kut.sh: uno strumento che cambia il modulo dell'host non gira mai
# in un ambiente di collaudo (qualunque *_FINTO) ne' come utente collaudo: guardia comune, prima di tutto.
. /mnt/linuxulator2/vm/wsl2/fbsd/caldo/guardia.sh	# 31/10/2026 (parere Opus sull'incidente): guardia comune delle azioni
guardia_azione || { echo "STOP: guardia: nessuno scambio"; exit 4; }
C=/mnt/linuxulator2/vm/wsl2/fbsd/caldo
L=/mnt/linuxulator2/vm/wsl2/fbsd/logs/modulo-caldo
umask 022
ulimit -c 0			# nessun core di questo script o dei suoi figli
mkdir -p "$L" && cd "$L" || { echo "cartella log $L non disponibile"; exit 4; }
MC_DIARIO=$L/diario.txt
MC_STATO=$L/stato.txt
. $C/mc-sistema.sh
. $C/mc-logica.sh
mc_main "$@"
