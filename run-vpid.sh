#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-vpid.sh.non-conforme
echo "INERTE: run-vpid.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-vpid.sh.non-conforme" >&2; exit 4
# Claude 24/10/2026 -- parere #45 §2: audit PASSIVO del ciclo di vita VPID01/VPID02 (dtrace/
# vpidaudit.d: CPU fisiche, migrazioni vere, cambi di VMCS12 fra ingressi in L2, INVVPID/INVEPT
# dell'L1) su UN avvio senza -x, modulo baseline. Derivato da run-x2apic.sh:
# (testo originale qui sotto)
# Claude 24/10/2026 -- parere #44 §8: prova A/B/A con x2APIC (bhyve -x) sul modulo baseline
# 0572294, a 2 VP. Tre AVVII della VM:
#   A1 12-Windows-11-vm12-senza-gpu         (come sempre, xAPIC)
#   B  12-Windows-11-vm12-senza-gpu-x2apic  (copia con -x)
#   A2 12-Windows-11-vm12-senza-gpu         (ritorno)
# In ogni avvio: C0 = 60 s di Windows senza WSL, poi una sessione WSL con la prova ext4 di
# faseA/gapmem.sh (W cicli di riscaldamento esclusi, D s di prova). Misure SOLO NATIVE, nessuna
# sonda DTrace (parere #43 §4, #44 §8): bhyvectl --get-stats per vCPU (VMEXIT_INST_EMUL = MMIO
# emulato, RDMSR/WRMSR, uscite totali, ingressi in L2, riflessioni, slow path), contatori TSC e
# vst_* (calib), tempo CPU dei thread vCPU; dalla prova, buchi e durata dei passi del ciclo.
# Fotografie a: inizio e fine C0, fine riscaldamento, fine prova.
D=${1:-480}; W=${2:-2}
B=/mnt/linuxulator2/vm/wsl2/fbsd; N=$B/freebsd-nested/tools/nested; C=$B/faseA
O=$B/logs/vpid-$(date +%Y%m%d-%H%M); T=$B/dtrace; mkdir -p "$O"
H=IP-HOST
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000\r' | iconv -f CP850 -t UTF-8 2>/dev/null; }
cpw() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$@"; }
task() {
	w "schtasks /create /tn $1 /tr \"$2\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn $1 >nul"
}
attendi_wsl() {
	k=0; while w "schtasks /query /tn claude-wsl /fo csv /nh" | /usr/bin/grep -qiE "esecuzione|running"; do sleep 5; k=$((k+1)); [ $k -gt 60 ] && break; done
}
wslrun() {
	printf '%s' "$1" > "$O/wsl-args.txt"
	cpw "$O/wsl-args.txt" marietto@win11:'C:/claude/wsl-args.txt'
	task claude-wsl "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1" > /dev/null
}
fase() { echo "FASE $1 $(date +%s.%N) $(date +%T)" | tee -a "$O/fasi.txt"; }
foto() {	# foto <etichetta>: contatori nativi
	{
		echo "FOTO $1 $(date +%s.%N)"
		sysctl hw.vmm.vmx.nested_l1_tsc hw.vmm.vmx.nested_l2_tsc
		sysctl hw.vmm.vmx | /usr/bin/grep -E "\.vst_"
		ps -H -o lwp,time,comm -p "$(pgrep -x bhyve | head -1)" | /usr/bin/grep vcpu
		for c in 0 1; do echo "== vcpu $c"; sudo -n bhyvectl --vm=vm0:12 --get-stats --cpu=$c; done
	} >> "$O/foto.txt" 2>&1
}
pausa() {
	w "if exist C:\\claude\\guardia-pausa (echo GIA) else (echo pausa > C:\\claude\\guardia-pausa & echo CREATA)" | tail -1
}
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
vmstat -w 1 > "$O/vmstat.txt" &
VS=$!
python3 "$C/tsecho.py" 7123 "$O/tsecho.txt" &
TS=$!
mount | /usr/bin/grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
sudo -n sysctl hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_scan_retries=1 hw.vmm.vmx.vept_verify_hpa=1 hw.vmm.vmx.vept_test_race=0 >/dev/null
md5 /boot/kernel/vmm-restore.ko > "$O/modulo.txt"
for F in A; do
	case $F in B) VMS=12-Windows-11-vm12-senza-gpu-x2apic ;; *) VMS=12-Windows-11-vm12-senza-gpu ;; esac
	echo "######## avvio $F ($VMS) $(date +%T)"
	echo "$F $VMS" >> "$O/configurazioni.txt"
	sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
	sudo -n sh "$N/$VMS" > "$O/script-$F.log" 2>&1 &
	i=0; while [ $i -lt 60 ] && [ ! -e /dev/vmm/vm0:12 ]; do sleep 1; i=$((i+1)); done
	[ -e /dev/vmm/vm0:12 ] || { echo "VM NON creata ($F)"; break; }
	i=0; until w "echo pronto" | /usr/bin/grep -q pronto; do sleep 10; i=$((i+10)); [ $i -gt 900 ] && break; done
	echo "ssh pronto dopo circa $i s"
	sudo -n dtrace -s "$T/vpidaudit.d" -o "$O/vpid.txt" 2>"$O/vpid.err" &
	sleep 90
	for f in gapmon.c memmon.c gapmem.sh; do cpw "$C/$f" marietto@win11:"C:/claude/faseA/$f"; done
	sh "$B/guardia-win.sh" aggiorna >> "$O/guardia.txt" 2>&1
	sleep 30
	echo "$F guardia: $(pausa)" >> "$O/guardia.txt"
	w "if exist %USERPROFILE%\\.wslconfig (echo .wslconfig PRESENTE) else (echo nessun .wslconfig)" >> "$O/configurazioni.txt"
	wslrun "--shutdown"; sleep 20; attendi_wsl
	fase "$F-C0"; foto "$F-C0-inizio"; sleep 60; foto "$F-C0-fine"
	w "del C:\\claude\\faseA\\gapmem-$F.log 2>nul & del C:\\claude\\wsl-log.txt 2>nul" > /dev/null
	fase "$F-wsl"
	wslrun "-d Debian -u root -- bash -c 'tr -d \"\\\\r\" < /mnt/c/claude/faseA/gapmem.sh > /root/gapmem.sh; bash /root/gapmem.sh $D $H $F $W'"
	r=0; k=0; MAXK=$(( (W * 150 + D + 900) / 10 ))
	until /usr/bin/grep -q GAP-FINE "$O/gapmem-$F.log" 2>/dev/null; do
		pgrep -x bhyve >/dev/null || { echo "BHYVE USCITO ($F)"; break; }
		sleep 10; k=$((k+1)); [ $k -gt $MAXK ] && { echo "fase $F non finita"; break; }
		cpw marietto@win11:"C:/claude/faseA/gapmem-$F.log" "$O/gapmem-$F.log" 2>/dev/null || continue
		if [ $r -eq 0 ] && /usr/bin/grep -q RISCALDAMENTO-FINE "$O/gapmem-$F.log"; then
			r=1; fase "$F-prova"; foto "$F-prova-inizio"
		fi
	done
	foto "$F-prova-fine"; fase "$F-fine"
	for f in gapmem-$F.log gapmem-pre-$F.txt gapmem-post-$F.txt gapmem-gapmon-$F.txt gapmem-memmon-$F.txt gapmem-dmesg-pre-$F.txt; do
		cpw marietto@win11:"C:/claude/faseA/$f" "$O/$f" 2>/dev/null || echo "manca $f" >> "$O/mancanti.txt"
	done
	echo "fase $F: buchi $(/usr/bin/grep -c '^BUCO' "$O/gapmem-gapmon-$F.txt" 2>/dev/null)"
	sh "$B/guardia-win.sh" riprendi >> "$O/guardia.txt" 2>&1
	w "schtasks /delete /tn claude-wsl /f" > /dev/null 2>&1
	w "shutdown /s /t 0" >/dev/null 2>&1
	i=0; while [ $i -lt 300 ] && pgrep -x bhyve >/dev/null; do sleep 2; i=$((i+2)); done
	pgrep -x bhyve >/dev/null && { echo "bhyve ANCORA VIVO ($F)"; break; } || echo "spegnimento ordinato dopo $i s ($F)"
	sleep 5
	sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
	sleep 10
done
sudo -n pkill -TERM -f vpidaudit.d; kill $TS $VS
sudo -n sysctl hw.vmm.vmx.vept_keep=0 hw.vmm.vmx.vept_verify_hpa=0 >/dev/null
echo "OUTPUT $O"
