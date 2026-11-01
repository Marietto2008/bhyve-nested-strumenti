#!/bin/sh
# approva-strumenti.sh -- Claude 31/10/2026, parere Opus sull'incidente, par. 4.2. Scrive APPROVATI-sequenza.sha256:
# lo sha di OGNI file che una sequenza esegue o carica, nel momento in cui gli strumenti sono stati RIVISTI.
# sequenza-kut.sh lo verifica all'avvio. Si rigenera SOLO dopo una revisione; lo sha dell'elenco va nell'autorizzazione.
# Uso: approva-strumenti.sh <motivo della revisione>   (rifiuta se l'elenco esiste: prima va archiviato con un nome nuovo)
set -u
W=/mnt/linuxulator2/vm/wsl2/linux
L=$W/APPROVATI-sequenza.sha256
[ $# = 1 ] || { echo "uso: $0 <motivo della revisione>"; exit 4; }
[ -e "$L" ] && { echo "STOP: $L esiste: archiviarlo prima con un nome nuovo"; exit 4; }
F="$W/sequenza-kut.sh $W/run-opnd-kut.sh $W/opnd-verdetto.py $W/opnd-manifest.sh $W/kut-drive.py $W/kld-loadcnt.d
$W/caldo/guardia.sh $W/caldo/vmm-residuo.sh $W/caldo/smoke-modulo.sh $W/caldo/modulo-caldo.sh $W/caldo/mc-logica.sh
$W/caldo/mc-sistema.sh $W/logs/stadio10-congelato-20261031/vmm-restore.ko $W/logs/kut-opnd-build-s10b/vmx-opnd.flat
/boot/kernel/vmm-restore.ko $W/installazione/files/usr/local/libexec/claude-vmm/gettone-lib.sh
$W/installazione/files/usr/local/libexec/claude-vmm/sonde-opnd-v2.d $W/freebsd-nested/tools/nested/ptpad-fbt-ripfix-nested.d $W/build-qemu-gate-nested-sr/qemu-system-x86_64
$W/sequenza-wsl.sh $W/run-wsl-corsa.sh $W/wsl-verdetto.py $W/campagna-wsl/vm0-12-wsl.sh $W/campagna-wsl/macchina.conf $W/wsl-passo.ps1
$W/installazione/files/usr/local/libexec/claude-vmm/sonde-wsl-v3.d $W/stage/current/sbin/bhyve
$W/logs/stadio11-congelato-20261101/vmm-restore.ko
$W/sequenza-p3.sh $W/run-p3-kut.sh $W/p3-verdetto.py $W/logs/kut-p3-build-2/x86/p3_contesa.flat $W/installazione/files/usr/local/libexec/claude-vmm/sonde-wsl-v1.d"	# 01/11: la campagna WSL (sonde v3, parere #172), lo stadio 11 congelato e il test di provocazione di P3	# l'ORIGINALE: il verso di ritorno (parere Opus sulla separazione par. 3.1)
{
	echo "# APPROVATI-sequenza.sha256 -- generato da approva-strumenti.sh il $(/bin/date '+%F %T'): $1"
	for f in $F; do
		[ -r "$f" ] || { echo "STOP: $f illeggibile" >&2; exit 4; }
		echo "$(/sbin/sha256 -q "$f") $f"
	done
} > "$L.nuovo" || exit 4
/bin/mv "$L.nuovo" "$L" && /bin/chmod 444 "$L" && echo "scritto $L ($(grep -vc '^#' "$L") file), sha $(/sbin/sha256 -q "$L")"
