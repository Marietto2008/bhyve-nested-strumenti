#!/bin/sh
# trappola-strumento.sh -- Claude 31/10/2026, parere Opus par. 3.3. Al posto di uno strumento VERO nei collaudi delle
# reti: registra l'invocazione e NON agisce. Una trappola scattata = una rete ha ceduto. Uscita 99.
echo "TRAPPOLA $* (utente $(/usr/bin/id -un))" >> "${SEQ_TRAPPOLE:-/dev/stderr}"
echo "TRAPPOLA: invocazione registrata, nessuna azione"
exit 99
