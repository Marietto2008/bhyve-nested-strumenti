#!/bin/sh
# tempesta-kvm.sh [svuota] -- Claude 09/11/2026, confronto KVM <-> bhyve (sotto LINUX).
# Un giro del riproduttore del panic LAPIC, identico a ciclo-tempeste.sh + prova-vhd.sh della campagna su
# FreeBSD (strumenti/campagna-wsl-originale/), con Windows raggiunta via l'inoltro di QEMU (127.0.0.1:2213):
#   FreeBSD ro7d come distro di sistema di WSL, freebsd-tempesta.sh = claude-lag 1200 100 (20 min).
# Con "svuota" (come il 05/11, panic al primo giro sotto bhyve) dopo l'EarlyConfig parte anche
# svuota-vmmem.ps1 (EmptyWorkingSet di vmmemWSL ogni secondo per 1100 s).
# Tutto quello che serve e' gia' in C:\claude del clone (VHD ro7d compreso: si controlla solo lo sha).
# Esito in ../dati-kvm/giro-<ora>.txt, console di FreeBSD in ../dati-kvm/console-<ora>.txt.
# CMDF=<file in C:\claude> cambia il comando eseguito in FreeBSD (di base freebsd-tempesta.sh), per esempio
# CMDF=freebsd-pti.sh per leggere vm.pmap.pti e le mitigazioni.
# AVVIO=prova-wsl-vhd-pti.ps1 avvia FreeBSD con il PTI acceso a forza (come lo ha da solo sotto bhyve).
set -u
SVUOTA=${1:-}
CMDF=${CMDF:-freebsd-tempesta.sh}
# AVVIO, non PS1: su FreeBSD sh imposta da solo PS1="$ " (10/11: il giro lanciava C:\claude\$ )
AVVIO=${AVVIO:-prova-wsl-vhd.ps1}
B=/mnt/linuxulator2/vm/confronto-kvm-bhyve
P=/home/marietto/.config/claude-wsl2/password-windows
SHA=$(cat /mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/fbsd152-wsl-ro7d.vhd.sha256)
win() { timeout ${2:-60} sshpass -f $P ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
	-o PreferredAuthentications=password -o ForwardX11=no -o ConnectTimeout=20 -p 2213 marietto@127.0.0.1 "$1" \
	2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r\0'; }
T=$(date +%Y%m%d-%H%M%S); R=$B/dati-kvm/giro-$T.txt; C=$B/dati-kvm/console-$T.txt
dica() { echo "$(date +%T) $*" | tee -a $R; }

dica "giro $T, svuota=${SVUOTA:-no}, comando=$CMDF, avvio=$AVVIO"
dica "pulizia WSL: $(win 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\claude\pulisci-wsl.ps1' 120 | tr '\n' ' ')"
h=$(win 'powershell -NoProfile -Command "(Get-FileHash C:\claude\wsl-fbsd\fbsd152-wsl-ro7d.vhd).Hash"' 300 | tr 'A-F' 'a-f' | grep -E '^[0-9a-f]{64}$')
[ "$h" = "$SHA" ] || { dica "SHA del VHD DIVERSO: '$h'"; exit 1; }
dica "sha ro7d ok"
win 'schtasks /end /tn ClaudeProvaWslVhd >nul 2>&1 & del C:\claude\wsl-fbsd\console-wsl.txt 2>nul & del C:\claude\prova-wsl-fbsd.log 2>nul & schtasks /create /tn ClaudeProvaWslVhd /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\claude\'"$AVVIO"' -Vhd fbsd152-wsl-ro7d -ComandoFile C:\claude\'"$CMDF"' -BootTimeout 0 -Utente root" /sc once /sd 01/01/2020 /st 00:00 /it /f >nul && schtasks /run /tn ClaudeProvaWslVhd' | tail -1 | tee -a $R

# Nessun segnale di partenza leggibile a giro in corso (09/11): la console la tiene aperta WSL, il registro
# della prova (trascrizione PowerShell) riceve l'output di claude-lag solo alla fine. svuota-vmmem parte
# subito: finche' vmmemWSL non esiste gira a vuoto, poi svuota ogni secondo per 1100 s.
if [ "$SVUOTA" = svuota ]; then
	win 'schtasks /create /tn ClaudeSvuota /tr "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\claude\svuota-vmmem.ps1" /sc once /sd 01/01/2020 /st 00:00 /it /rl highest /f >nul && schtasks /run /tn ClaudeSvuota' | tail -1 | tee -a $R
	dica "svuota-vmmem avviato"
fi

# fine della prova (ESITO nel registro di prova-wsl-fbsd.ps1), al massimo 25 min dopo l'EarlyConfig
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 1500 ]; do
	win 'type C:\claude\prova-wsl-fbsd.log' | grep -q ESITO && break
	sleep 20
done
win 'type C:\claude\wsl-fbsd\console-wsl.txt' 120 | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' > $C
win 'type C:\claude\prova-wsl-fbsd.log' | sed -n '/ESITO/,$p' | tee -a $R
[ "$SVUOTA" = svuota ] && win 'type C:\claude\svuota-vmmem.log' | tail -3 | tee -a $R
win 'schtasks /end /tn ClaudeSvuota >nul 2>&1 & schtasks /delete /tn ClaudeSvuota /f >nul 2>&1 & schtasks /delete /tn ClaudeProvaWslVhd /f >nul 2>&1 & echo attivita cancellate' | tee -a $R
if grep -q 'Fatal trap' $C; then
	dica "PANIC: $(grep -m1 -A12 'Fatal trap' $C | grep -E 'fault virtual address|instruction pointer|fault code' | tr -s ' ' | tr '\n' ' ')"
else
	dica "nessun panic (console $(wc -l < $C) righe)"
fi
