#!/bin/sh
# tempesta-hyperv.sh [giri] -- Claude 13/11/2026, prova chiesta dall'utente: FreeBSD 15.2 (stessa ro7d) come VM normale di
# Hyper-V Manager («FreeBSD-15.2», Gen 2, 8 vCPU, timer LAPIC forzato) dentro la Windows annidata sotto bhyve, niente WSL.
# Per ogni giro: VM spenta e riaccesa, attesa di SSH (via Windows: la VM e' sul Default Switch), claude-lag 1200 100 in
# background, poi controllo ogni 5 s della console (COM1 -> C:\claude\hyperv\console.txt) e del processo, fino a «Fatal trap»
# (console e record del registratore salvati), alla fine di claude-lag o a 30 min. Esiti in ../hyperv/giri-hyperv.txt.
set -u
N=${1:-5}
D=/mnt/linuxulator2/vm/confronto-kvm-bhyve
H=$D/hyperv
P=/home/marietto/.config/claude-wsl2/password-windows
WIN=${WIN_IP:-$(arp -an | awk '/00:a0:98:a1:73:65/ {gsub(/[()]/, "", $2); print $2; exit}')}
WIN=${WIN:-IP-WINDOWS-A}
G=$H/giri-hyperv.txt
win() { timeout ${2:-60} sshpass -f $P ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
	-o PreferredAuthentications=password -o ConnectTimeout=20 marietto@$WIN "$1" 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c | tr -d '\r\0'; }
fb() { timeout ${2:-30} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=15 \
	-o ProxyCommand="sshpass -f $P ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o PreferredAuthentications=password -W %h:%p marietto@$WIN" \
	root@$IP "$1" 2>/dev/null; }
s() { sysctl -n hw.vmm.vmx.$1; }
pf() { echo $(( $(s nested_diag_pfrec_pf_fetch) + $(s nested_diag_pfrec_pf_data) )); }
dica() { echo "$(date +%T) $*" | tee -a $G; }

dica "tempesta-hyperv: $N giri, Windows $WIN, modulo $(sha256 -q /boot/kernel/vmm-restore.ko | cut -c1-8), apic_access=$(s nested_apic_access) qual_kvm=$(s nested_qual_kvm)"
k=1
while [ $k -le $N ]; do
	win 'powershell -NoProfile -Command "Stop-VM -Name FreeBSD-15.2 -TurnOff -Force -ErrorAction SilentlyContinue; Start-Sleep 3; Start-VM -Name FreeBSD-15.2"' 120 >/dev/null
	L0=$(win 'powershell -NoProfile -Command "(Get-Content C:\claude\hyperv\console.txt -ErrorAction SilentlyContinue).Count"' | tail -1); L0=${L0:-0}
	dica "giro $k di $N: VM riaccesa (console da riga $L0)"
	IP=; t0=$(date +%s)
	while [ $(( $(date +%s) - t0 )) -lt 240 ]; do
		sleep 10
		IP=$(win 'powershell -NoProfile -Command "(Get-VMNetworkAdapter -VMName FreeBSD-15.2).IPAddresses"' | /usr/bin/grep -E '^[0-9.]+$' | head -1)
		[ -n "$IP" ] && fb 'echo pronto' | /usr/bin/grep -q pronto && break
		IP=
	done
	[ -n "$IP" ] || { dica "  la VM non risponde in SSH dopo 4 min: STOP"; exit 4; }
	p0=$(pf); e0=$(s nested_diag_pfrec_e0)
	fb 'daemon -f -o /var/log/claude-lag.log /usr/local/bin/claude-lag 1200 100; sleep 1; pgrep -q claude-lag && echo partito' | /usr/bin/grep -q partito || { dica "  claude-lag non parte: STOP"; exit 4; }
	ti=$(date +%s); dica "  tempesta partita su $IP ($((ti - t0)) s dall'accensione)"
	esito=TEMPO
	while [ $(( $(date +%s) - ti )) -lt 1800 ]; do
		sleep 5
		r=$(win "powershell -NoProfile -Command \"Get-Content C:\\claude\\hyperv\\console.txt | Select-Object -Skip $L0 | Select-String -Pattern Fatal -SimpleMatch | Select-Object -First 1\"" 30)
		if echo "$r" | /usr/bin/grep -q 'Fatal trap'; then esito=PANIC; break; fi
		if [ $(( ($(date +%s) - ti) % 60 )) -lt 5 ]; then
			fb 'pgrep -q claude-lag && echo vivo || echo finito' | /usr/bin/grep -q finito && { esito=FINE; break; }
		fi
	done
	sleep 5
	T=$(date +%Y%m%d-%H%M%S); C=$H/console-hyperv-$T.txt
	win "powershell -NoProfile -Command \"Get-Content C:\\claude\\hyperv\\console.txt | Select-Object -Skip $L0\"" 120 | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' > $C
	p1=$(pf); e1=$(s nested_diag_pfrec_e0)
	[ $p1 -gt $p0 ] && s nested_diag_pfrec_dump > $H/registratore-hyperv-$T.txt
	if [ $esito = PANIC ]; then
		dica "  PANIC a $(( $(date +%s) - ti )) s (+-5) dall'inizio della tempesta: $(/usr/bin/grep -a -m1 -A12 'Fatal trap' $C | /usr/bin/grep -a -E 'instruction pointer|fault code|current thread' | tr -s ' \t' ' ' | tr '\n' ' ')"
	else
		dica "  $esito dopo $(( $(date +%s) - ti )) s di tempesta"
	fi
	dica "  E0 +$((e1 - e0)), #PF registrati +$((p1 - p0)) | $C"
	k=$((k + 1))
done
win 'powershell -NoProfile -Command "Stop-VM -Name FreeBSD-15.2 -TurnOff -Force"' 120 >/dev/null
dica "fine (VM spenta)"
