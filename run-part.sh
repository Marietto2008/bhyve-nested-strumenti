#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-part.sh.non-conforme
echo "INERTE: run-part.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-part.sh.non-conforme" >&2; exit 4
# Claude 23/10/2026 -- parere #36 §7: diagnostica di L0 per partizione (dtrace/partdiag.d)
# a 2 VP reali, con la stessa prova ext4 di gapcg-20261023-1912 (faseA/gapcg.sh: tre fasi
# da D s; la fase "B" non tocca nulla, la catena non ha limiti), cosi' i buchi si
# confrontano con quelli senza la sonda (25/35/29).
# Prima della compilazione, fasi di identificazione dei contesti EPTP12, con l'ora sul
# file fasi.txt: F0 solo Windows (dopo wsl --shutdown), F1 WSL avviato e inattivo,
# F2 WSL che lavora (2 x yes), F3 dopo wsl --shutdown.
# Contatori Hyper-V per VP da Windows (faseA/hvperf.ps1) durante la prova.
# Modulo come la corsa di confronto: vept_keep=1, retry 1, verifica HPA accesa.
# Memoria dell'host: vmstat 1, swapinfo ogni 30 s (parere #37 §6).
D=${1:-480}
B=/mnt/linuxulator2/vm/wsl2/linux; N=$B/freebsd-nested/tools/nested; C=$B/faseA; T=$B/dtrace
O=$B/logs/part-$(date +%Y%m%d-%H%M); mkdir -p "$O"
H=IP-HOST
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
cpw() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$@"; }
task() {	# task <nome> <comando>: lanciato nella sessione dell'utente
	w "schtasks /create /tn $1 /tr \"$2\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn $1 >nul"
}
ms() { python3 -c 'import time; print(time.time_ns() // 1000000)'; }
woff() {	# scarto dell'orologio di Windows rispetto all'host
	a=$(ms); x=$(w "powershell -NoProfile -Command [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()" | tr -dc '0-9'); b=$(ms)
	echo "WINOFF $1 host_prima=$a windows=$x host_dopo=$b scarto_ms=$(( x - (a + b) / 2 )) incertezza_ms=$(( (b - a) / 2 ))" | tee -a "$O/winoff.txt"
}
wslrun() {	# wslrun <argomenti di wsl.exe>: nella sessione dell'utente, senza attendere
	printf '%s' "$1" > "$O/wsl-args.txt"
	cpw "$O/wsl-args.txt" marietto@win11:'C:/claude/wsl-args.txt'
	task claude-wsl "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1" > /dev/null
}
fase() { echo "FASE $1 $(date +%s.%N) $(date +%T)" | tee -a "$O/fasi.txt"; }
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
echo "== host prima: $(swapinfo -h | tail -1)"
vmstat -w 1 > "$O/vmstat.txt" &
VS=$!
( while :; do echo "$(date +%T) $(swapinfo -k | tail -1)"; sleep 30; done ) > "$O/swap.txt" &
SW=$!
mount | /usr/bin/grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
sudo -n sysctl hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_scan_retries=1 hw.vmm.vmx.vept_verify_hpa=1 hw.vmm.vmx.vept_test_race=0 >/dev/null
python3 "$C/tsecho.py" 7123 "$O/tsecho.txt" &
TS=$!
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n dtrace -s "$T/gaphost.d" -o "$O/gaphost.txt" 2>"$O/gaphost.err" &
sudo -n dtrace -s "$T/win-lat.d" -o "$O/lat.txt" 2>"$O/lat.err" &
sudo -n dtrace -s "$T/partdiag.d" -o "$O/part.txt" 2>"$O/part.err" &
sleep 4
sudo -n sh "$N/${VMS:-12-Windows-11-vm12-senza-gpu}" > "$O/script.log" 2>&1 &
i=0; while [ $i -lt 60 ] && [ ! -e /dev/vmm/vm0:12 ]; do sleep 1; i=$((i+1)); done
[ -e /dev/vmm/vm0:12 ] || { echo "VM NON creata"; kill $TS $VS $SW; sudo -n pkill -TERM -f "gaphost.d|win-lat.d|partdiag.d"; exit 1; }
i=0; until w "echo pronto" | /usr/bin/grep -q pronto; do sleep 10; i=$((i+10)); [ $i -gt 900 ] && break; done
echo "ssh pronto dopo circa $i s"
w "schtasks /delete /tn claude-vita /f & schtasks /delete /tn claude-clk /f" > /dev/null 2>&1
sleep 90
w "powershell -NoProfile -Command \"(Get-CimInstance Win32_ComputerSystem | Select-Object NumberOfLogicalProcessors | Format-List | Out-String).Trim()\"" | tee "$O/topologia.txt"
for f in gapmon.c cgmon.c gapcg.sh hvperf.ps1; do cpw "$C/$f" marietto@win11:"C:/claude/faseA/$f"; done
# identificazione dei contesti
echo "######## identificazione $(date +%T)"
wslrun "--shutdown"; sleep 20
w "wsl --list --running" | tr -d '\r' > "$O/wsl-running-F0.txt"
fase F0-solo-windows; sleep 60
fase F1-wsl-avvio
wslrun "-d Debian -u root -- sleep 75"; sleep 80
fase F2-wsl-lavora
wslrun "-d Debian -u root -- sh -c 'timeout 60 yes >/dev/null & timeout 60 yes >/dev/null; wait'"; sleep 70
fase F3-wsl-shutdown
wslrun "--shutdown"; sleep 60
fase F4-fine-identificazione
echo "######## carico prima delle prove $(date +%T)"
fase P0-compilazione
sh "$C/kb-ab.sh" PARTPRE kbuild4.sh 2>&1 | /usr/bin/grep -E "^real|kernel rc|bhyve CPU"
sleep 30
echo "######## prova ext4 $(date +%T)"
woff inizio
task claude-hvperf "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\faseA\\hvperf.ps1 -Sec $((3 * (D + 40) + 120))" > /dev/null
fase P1-prova
printf '%s' "-d Debian -u root -- bash -c 'tr -d \"\\\\r\" < /mnt/c/claude/faseA/gapcg.sh > /root/gapcg.sh; bash /root/gapcg.sh $D $H'" > "$O/args.txt"
cpw "$O/args.txt" marietto@win11:'C:/claude/wsl-args.txt'
w "del C:\\claude\\faseA\\gapcg.log 2>nul & del C:\\claude\\wsl-log.txt 2>nul" > /dev/null
task claude-wsl "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1" > /dev/null
k=0
until cpw marietto@win11:"C:/claude/faseA/gapcg.log" "$O/gapcg.log" 2>/dev/null && /usr/bin/grep -q GAP-FINE "$O/gapcg.log"; do
	pgrep -x bhyve >/dev/null || { echo "BHYVE USCITO"; break; }
	sleep 30; k=$((k+1)); [ $k -gt $(( (3 * (D + 40)) / 30 + 40 )) ] && { echo "prova non finita"; break; }
done
fase P2-fine-prova
woff fine
for F in A1 B A2; do
	cpw marietto@win11:"C:/claude/faseA/gapcg-gapmon-$F.txt" "$O/gapmon-$F.txt" 2>/dev/null
	cpw marietto@win11:"C:/claude/faseA/gapcg-cgmon-$F.txt" "$O/cgmon-$F.txt" 2>/dev/null
	echo "fase $F: buchi $(/usr/bin/grep -c '^BUCO' "$O/gapmon-$F.txt" 2>/dev/null)"
done
sleep 60
cpw marietto@win11:'C:/claude/faseA/hvperf.csv' "$O/hvperf.csv" 2>/dev/null
cpw marietto@win11:'C:/claude/faseA/hvperf-insiemi.txt' "$O/hvperf-insiemi.txt" 2>/dev/null
cpw marietto@win11:'C:/claude/wsl-log.txt' "$O/wsl-log.txt" 2>/dev/null
/usr/bin/grep -E "B:|non compila|NON spostato|cgroup2" "$O/gapcg.log"
w "schtasks /delete /tn claude-wsl /f & schtasks /delete /tn claude-hvperf /f" > /dev/null 2>&1
w "shutdown /s /t 0" >/dev/null 2>&1
i=0; while [ $i -lt 300 ] && pgrep -x bhyve >/dev/null; do sleep 2; i=$((i+2)); done
pgrep -x bhyve >/dev/null && echo "bhyve ANCORA VIVO" || echo "spegnimento ordinato dopo $i s"
sleep 3
sudo -n pkill -TERM -f "gaphost.d|win-lat.d|partdiag.d"; kill $TS $VS $SW
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n sysctl hw.vmm.vmx.vept_keep=0 hw.vmm.vmx.vept_verify_hpa=0 >/dev/null
echo "== host dopo: $(swapinfo -h | tail -1)"
echo "OUTPUT $O"
