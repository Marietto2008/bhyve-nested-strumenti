#!/bin/sh
# tempesta-whpx.sh [giri] -- Claude 12/11/2026, prova chiesta dall'utente: la configurazione del post r/freebsd (QEMU 9.0
# per Windows con -accel whpx) DENTRO la Windows annidata sotto bhyve, senza WSL. Stessa FreeBSD (copia di ro7d con
# claude-lag 1200 100 lanciato da rc.local e spegnimento alla fine), stesso modulo e registratore in L0.
# Per ogni giro: avvia l'attivita' ClaudeWhpx (avvia-whpx.ps1), segue la console ogni 5 s fino a «Fatal trap»
# (panic: console e record del registratore salvati, QEMU chiuso), a «tempesta fine» o all'uscita di QEMU (esito.txt),
# al massimo 30 min. SVUOTA=1 avvia anche svuota-processo.ps1 sul processo di QEMU 120 s dopo l'avvio.
# Esiti in ../qemu-whpx/giri-whpx.txt.
set -u
N=${1:-5}
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
Q=$D/qemu-whpx
P=/home/marietto/.config/claude-wsl2/password-windows
WIN=${WIN_IP:-$(arp -an | awk '/00:a0:98:a1:73:65/ {gsub(/[()]/, "", $2); print $2; exit}')}
WIN=${WIN:-IP-WINDOWS-A}
G=$Q/giri-whpx.txt
win() { timeout ${2:-60} sshpass -f $P ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
	-o PreferredAuthentications=password -o ConnectTimeout=20 marietto@$WIN "$1" 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r\0'; }
s() { sysctl -n hw.vmm.vmx.$1; }
pf() { echo $(( $(s nested_diag_pfrec_pf_fetch) + $(s nested_diag_pfrec_pf_data) )); }
dica() { echo "$(date +%T) $*" | tee -a $G; }

dica "tempesta-whpx: $N giri, attivita ${TASK:-ClaudeWhpx}, Windows $WIN, svuota=${SVUOTA:-0}, modulo $(sha256 -q /boot/kernel/vmm-restore.ko | cut -c1-8), apic_access=$(s nested_apic_access) qual_kvm=$(s nested_qual_kvm)"
k=1
while [ $k -le $N ]; do
	win 'taskkill /f /im qemu-system-x86_64.exe >nul 2>&1 & schtasks /end /tn ClaudeSvuota >nul 2>&1 & del C:\claude\qemu-whpx\console.txt C:\claude\qemu-whpx\esito.txt 2>nul' >/dev/null
	p0=$(pf); e0=$(s nested_diag_pfrec_e0); t0=$(date +%s)
	dica "giro $k di $N: avvio"
	win "schtasks /run /tn ${TASK:-ClaudeWhpx}" >/dev/null
	sv=0; esito=TEMPO; ti=
	while [ $(( $(date +%s) - t0 )) -lt 1800 ]; do
		sleep 5
		r=$(win 'powershell -NoProfile -Command "if (Test-Path C:\claude\qemu-whpx\esito.txt) { echo ESITO-QEMU }; if (Test-Path C:\claude\qemu-whpx\console.txt) { Select-String -Path C:\claude\qemu-whpx\console.txt -Pattern Fatal,tempesta -SimpleMatch | ForEach-Object { $_.Line } }"' 30)
		[ -z "$ti" ] && echo "$r" | /usr/bin/grep -q 'tempesta inizio' && { ti=$(date +%s); dica "  tempesta partita ($((ti - t0)) s dall'avvio)"; }
		if echo "$r" | /usr/bin/grep -q 'Fatal trap'; then esito=PANIC; break; fi
		if echo "$r" | /usr/bin/grep -q 'tempesta fine\|ESITO-QEMU'; then esito=FINE; break; fi
		if [ "${SVUOTA:-0}" = 1 ] && [ $sv = 0 ] && [ -n "$ti" ] && [ $(( $(date +%s) - ti )) -ge 120 ]; then
			win 'schtasks /create /tn ClaudeSvuota /tr "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\claude\qemu-whpx\svuota-processo.ps1" /sc once /sd 01/01/2020 /st 00:00 /it /rl highest /f >nul && schtasks /run /tn ClaudeSvuota' >/dev/null
			sv=1; dica "  svuotamento del processo di QEMU avviato"
		fi
	done
	T=$(date +%Y%m%d-%H%M%S); C=$Q/console-whpx-$T.txt
	win 'type C:\claude\qemu-whpx\console.txt' 120 | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' > $C
	p1=$(pf); e1=$(s nested_diag_pfrec_e0)
	[ $p1 -gt $p0 ] && s nested_diag_pfrec_dump > $Q/registratore-whpx-$T.txt
	if [ $esito = PANIC ]; then
		dica "  PANIC a $(( $(date +%s) - ${ti:-$t0} )) s (+-5) dall'inizio della tempesta: $(/usr/bin/grep -a -m1 -A12 'Fatal trap' $C | /usr/bin/grep -a -E 'instruction pointer|fault code|current thread' | tr -s ' \t' ' ' | tr '\n' ' ')"
	else
		dica "  $esito dopo $(( $(date +%s) - t0 )) s, console $(wc -l < $C) righe"
	fi
	dica "  E0 +$((e1 - e0)), #PF registrati +$((p1 - p0)) | $C"
	win 'taskkill /f /im qemu-system-x86_64.exe >nul 2>&1 & schtasks /end /tn ClaudeSvuota >nul 2>&1 & schtasks /delete /tn ClaudeSvuota /f >nul 2>&1' >/dev/null
	sleep 5
	k=$((k + 1))
done
dica "fine"
