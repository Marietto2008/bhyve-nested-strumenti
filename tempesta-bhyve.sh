#!/bin/sh
# tempesta-bhyve.sh [svuota] -- Claude 10/11/2026, confronto KVM <-> bhyve (sotto FREEBSD, configurazione A:
# vm0-13-qemu.sh --qemu-sipi --audio, QEMU -accel bhyve, vept_keep=1). Copia di tempesta-kvm.sh con Windows a
# IP-WINDOWS-B:22 (immagine del G-DRIVE) ed esiti in ../dati-bhyve/. Prima del giro copia in C:\claude gli
# involucri ps1 e i comandi FreeBSD di questa cartella. In fondo stampa i contatori nested del modulo.
# --- testo originale di tempesta-kvm.sh:
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
# 12/11 17:1x: dopo la riparazione della linea il DHCP di Fastweb ha dato a Windows .53 invece di .54: l'indirizzo
# si ricava dal MAC di vm0:13 nella tabella ARP (WIN_IP lo forza); se manca, un ping a .50-.60 riempie la tabella.
win_ip() {
	a=$(arp -an | awk '/00:a0:98:a1:73:65/ {gsub(/[()]/, "", $2); print $2; exit}')
	if [ -z "$a" ]; then
		for i in $(seq 50 60); do ping -c1 -t1 RETE-LAN.$i >/dev/null 2>&1; done
		a=$(arp -an | awk '/00:a0:98:a1:73:65/ {gsub(/[()]/, "", $2); print $2; exit}')
	fi
	echo ${a:-IP-WINDOWS-B}
}
WIN=${WIN_IP:-$(win_ip)}
for f in prova-wsl-vhd-pti.ps1 prova-wsl-vhd-nopti.ps1 freebsd-kenv.sh freebsd-pti.sh; do [ -f $B/strumenti/$f ] && sshpass -f $P scp -q -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=20 $B/strumenti/$f "marietto@$WIN:C:/claude/$f"; done
win() { timeout ${2:-60} sshpass -f $P ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
	-o PreferredAuthentications=password -o ForwardX11=no -o ConnectTimeout=20 marietto@$WIN "$1" \
	2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r\0'; }
T=$(date +%Y%m%d-%H%M%S); R=$B/dati-bhyve/giro-$T.txt; C=$B/dati-bhyve/console-$T.txt
dica() { echo "$(date +%T) $*" | tee -a $R; }

dica "giro $T, svuota=${SVUOTA:-no}, comando=$CMDF, avvio=$AVVIO"
dica "pulizia WSL: $(win 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\claude\pulisci-wsl.ps1' 120 | tr '\n' ' ')"
# 11/11 23:26: subito dopo l'avvio di Windows lo sha non e' arrivato in 300 s (come sotto KVM alle 03:51): fino a 3
# tentativi, ognuno annotato con la sua durata (come tempesta-kvm2.sh)
t=1; h=
while [ $t -le 3 ] && [ -z "$h" ]; do
	s0=$(date +%s)
	h=$(win 'powershell -NoProfile -Command "(Get-FileHash C:\claude\wsl-fbsd\fbsd152-wsl-ro7d.vhd).Hash"' 300 | tr 'A-F' 'a-f' | grep -E '^[0-9a-f]{64}$')
	dica "sha tentativo $t: $(( $(date +%s) - s0 )) s${h:+ (letto)}"
	t=$((t + 1))
done
[ "$h" = "$SHA" ] || { dica "SHA del VHD DIVERSO: '$h'"; exit 1; }
dica "sha ro7d ok"
win 'schtasks /end /tn ClaudeProvaWslVhd >nul 2>&1 & del C:\claude\wsl-fbsd\console-wsl.txt 2>nul & del C:\claude\prova-wsl-fbsd.log 2>nul & schtasks /create /tn ClaudeProvaWslVhd /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\claude\'"$AVVIO"' -Vhd fbsd152-wsl-ro7d -ComandoFile C:\claude\'"$CMDF"' -BootTimeout 0 -Utente root" /sc once /sd 01/01/2020 /st 00:00 /it /f >nul && schtasks /run /tn ClaudeProvaWslVhd' | tail -1 | tee -a $R

# Nessun segnale di partenza leggibile a giro in corso (09/11): la console la tiene aperta WSL, il registro
# della prova (trascrizione PowerShell) riceve l'output di claude-lag solo alla fine. svuota-vmmem parte
# subito: finche' vmmemWSL non esiste gira a vuoto, poi svuota ogni secondo per 1100 s.
# 10/11 sotto bhyve: con svuota-vmmem acceso fin dall'avvio FreeBSD non arrivava al multiutente in tempo
# (CreateVm ERROR_TIMEOUT dopo 65 s, fermo a «Mounting local filesystems»). Si aspetta l'avvio (~40 s qui).
if [ "$SVUOTA" = svuota ]; then
	sleep ${SVUOTA_RITARDO:-120}
	win 'schtasks /create /tn ClaudeSvuota /tr "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\claude\svuota-vmmem.ps1 -PausaMs '"${SVUOTA_PAUSA:-1000}"'" /sc once /sd 01/01/2020 /st 00:00 /it /rl highest /f >nul && schtasks /run /tn ClaudeSvuota' | tail -1 | tee -a $R
	dica "svuota-vmmem avviato (pausa ${SVUOTA_PAUSA:-1000} ms)"
fi

# fine della prova (ESITO nel registro di prova-wsl-fbsd.ps1), al massimo 25 min dopo l'EarlyConfig
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 1500 ]; do
	win 'type C:\claude\prova-wsl-fbsd.log' | grep -q ESITO && break
	sleep 20
done
win 'type C:\claude\wsl-fbsd\console-wsl.txt' 120 | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' > $C
# 15/11 (claude): la trascrizione INTERA in dati-bhyve/prova-log-<ora>.txt: l'uscita di claude-lag (righe dei buchi:
# ora, CPU, durata) sta PRIMA di ESITO e finora si perdeva. In $R resta la parte da ESITO in poi.
win 'type C:\claude\prova-wsl-fbsd.log' > $B/dati-bhyve/prova-log-$T.txt
sed -n '/ESITO/,$p' $B/dati-bhyve/prova-log-$T.txt | tee -a $R
[ "$SVUOTA" = svuota ] && win 'type C:\claude\svuota-vmmem.log' | tail -3 | tee -a $R
win 'schtasks /end /tn ClaudeSvuota >nul 2>&1 & schtasks /delete /tn ClaudeSvuota /f >nul 2>&1 & schtasks /delete /tn ClaudeProvaWslVhd /f >nul 2>&1 & echo attivita cancellate' | tee -a $R
if grep -q 'Fatal trap' $C; then
	dica "PANIC: $(grep -m1 -A12 'Fatal trap' $C | grep -E 'fault virtual address|instruction pointer|fault code' | tr -s ' ' | tr '\n' ' ')"
else
	dica "nessun panic (console $(wc -l < $C) righe)"
fi
dica "modulo: $(kldstat -v | grep -o 'vmm-restore.ko ([^)]*)' | head -1) vept_keep=$(sysctl -n hw.vmm.vmx.vept_keep) nested_apic_access=$(sysctl -n hw.vmm.vmx.nested_apic_access) apicacc l1_wants=$(sysctl -n hw.vmm.vmx.nested_apicacc_l1_wants 2>/dev/null) exits=$(sysctl -n hw.vmm.vmx.nested_apicacc_exits 2>/dev/null)"
