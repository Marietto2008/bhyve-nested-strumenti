#!/bin/sh
# finto-sudo.sh -- Claude 31/10/2026, parere Opus sulla separazione par. 1.2. Imita sudo per i collaudi, SENZA privilegi:
# il comando gira come FIGLIO di questo processo (come sotto sudo) e SIGINT non gli viene inoltrato (sudo non inoltra i
# segnali del proprio gruppo di processi). Esce quando il figlio esce.
trap '' INT
"$@" &
wait $!
