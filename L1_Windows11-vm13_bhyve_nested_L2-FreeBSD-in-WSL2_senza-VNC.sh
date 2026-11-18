#!/bin/sh
# NON e' lo script vero: e' solo un rimando.          [claude 07/11/2026]
# Il vero sta in /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/vm0-13-wsl2-freebsd.sh : fa parte della campagna WSL
# (git e altri file dipendono da quel percorso), quindi non si sposta. Un rimando non puo' invecchiare.
exec /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/vm0-13-wsl2-freebsd.sh "$@"
