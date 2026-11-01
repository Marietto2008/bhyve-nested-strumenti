#!/bin/sh
# controllo-azioni.sh -- Claude 01/11/2026. Involucro: la logica (v3, per occorrenza di sudo, parere Opus «letture
# chiuse» par. 3.1-3.3) e' in controllo-azioni.py. Stessi argomenti, stesse uscite (0 conforme, 1 difetti).
exec python3 /mnt/linuxulator2/vm/wsl2/linux/controllo-azioni.py "$@"
