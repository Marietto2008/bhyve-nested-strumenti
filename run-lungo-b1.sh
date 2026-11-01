#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-lungo-b1.sh.non-conforme
echo "INERTE: run-lungo-b1.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-lungo-b1.sh.non-conforme" >&2; exit 4
# Claude 22/10/2026 -- parere #30 §6, seconda parte: sessione lunga con B1
# (vept_keep=1, retry 1, verifica HPA). Windows + WSL2: load.sh (stress-ng 30 min,
# compilazione, 5 cicli I/O con SHA-256 su ext4 e NTFS, clockmon), poi 20 cicli
# wsl --shutdown (ciclovita.ps1), poi spegnimento ordinato. Latenze degli
# interrupt dell'L1 (win-lat.d), contatori B1 prima/dopo. Log in logs/lungoB1-*.
B=/mnt/linuxulator2/vm/wsl2/linux; N=$B/freebsd-nested/tools/nested; D=$B/dtrace; C=$B/faseA
O=$B/logs/lungoB1-$(date +%Y%m%d-%H%M); mkdir -p $O
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
cpw() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$@"; }
ctr() { sysctl hw.vmm.vmx | /usr/bin/grep -E "vept_|nested_" | sed 's/^hw.vmm.vmx.//'; }
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | /usr/bin/grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
sudo -n sysctl hw.vmm.vmx.diag_efer=0 hw.vmm.vmx.vept_diag=0 hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_scan_retries=1 hw.vmm.vmx.vept_verify_hpa=1 hw.vmm.vmx.vept_test_race=0 hw.vmm.vmx.vept_scan_max_ns=0 hw.vmm.vmx.vept_t_scan_max_ns=0 hw.vmm.vmx.vept_t_partial_max_ns=0 hw.vmm.vmx.vept_t_full_max_ns=0 hw.vmm.vmx.nested_invept_ns_max=0 hw.vmm.vmx.vept_t_verify_max_ns=0 >/dev/null
ctr > $O/ctr.prima
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n dtrace -s $D/win-lat.d -o $O/lat.txt 2>$O/lat.err &
sudo -n dtrace -s $D/b1keep.d -o $O/b1keep.txt 2>$O/b1keep.err &
sleep 4
sudo -n sh $N/${VMS:-12-Windows-11-vm12-senza-gpu} > $O/script.log 2>&1 &
i=0; while [ $i -lt 60 ]; do [ -e /dev/vmm/vm0:12 ] && break; sleep 1; i=$((i+1)); done
[ -e /dev/vmm/vm0:12 ] || { echo "VM NON creata"; exit 1; }
# TOLTO 23/10: xdotool windowminimize su TigerVNC fa crollare openbox (client_calc_layer), vedi memoria
T0=$(date +%s)
i=0; until w "echo pronto" | /usr/bin/grep -q pronto; do
	pgrep -x bhyve >/dev/null || { echo "BHYVE USCITO durante l'avvio"; exit 1; }
	sleep 10; i=$((i+10)); [ $i -gt 900 ] && { echo "SSH non risponde dopo 900 s"; break; }
done
echo "ssh pronto dopo $(( $(date +%s) - T0 )) s" | tee $O/avvio.txt
w "schtasks /delete /tn claude-vita /f & schtasks /delete /tn claude-clk /f" > $O/task-vecchi.txt 2>&1
( while pgrep -x bhyve >/dev/null; do echo "$(date +%T) $(sysctl -n hw.vmm.vmx.vept_shadow_pages)"; sleep 60; done ) > $O/shadow-pages.txt &
sleep 90
w "powershell -NoProfile -Command \"(Get-CimInstance Win32_ComputerSystem | Select-Object NumberOfProcessors,NumberOfLogicalProcessors | Format-List | Out-String).Trim()\"" > $O/topologia.txt 2>&1
echo "topologia: $(tr -s ' \r\n' ' ' < $O/topologia.txt)"
P=$(pgrep -x bhyve); ps -H -o lwp,time,comm -p $P | /usr/bin/grep -i vcpu > $O/vcpu-prima.txt
# 1. carico in WSL
for f in ${LOADSH:-load.sh} io.sh clockmon.c; do cpw $C/$f marietto@win11:"C:/claude/faseA/$f"; done
printf '%s' "-d Debian -u root -- bash -c 'tr -d \"\\\\r\" < /mnt/c/claude/faseA/${LOADSH:-load.sh} > /root/load.sh; bash /root/load.sh'" > $O/args.txt
cpw $O/args.txt marietto@win11:'C:/claude/wsl-args.txt'
echo "carico: $(date +%T)" | tee -a $O/fasi.txt
w "del C:\\claude\\faseA\\load.log 2>nul & del C:\\claude\\wsl-log.txt 2>nul & schtasks /create /tn claude-wsl /tr \"powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn claude-wsl" > /dev/null
k=0
until cpw marietto@win11:'C:/claude/faseA/load.log' $O/load.log 2>/dev/null && /usr/bin/grep -q LOAD-FINE $O/load.log; do
	pgrep -x bhyve >/dev/null || { echo "BHYVE USCITO durante il carico"; break; }
	sleep 60; k=$((k+1)); [ $k -gt 240 ] && { echo "carico non finito in 4 h"; break; }
done
echo "fine carico: $(date +%T)" | tee -a $O/fasi.txt
cpw marietto@win11:'C:/claude/faseA/clockmon.log' $O/clockmon.log 2>/dev/null
w "type C:\\claude\\wsl-log.txt" > $O/wsl-log.txt
# 2. 20 cicli wsl --shutdown, con un task creato apposta (trigger nel 2030) e poi cancellato
cpw $C/ciclovita.ps1 marietto@win11:'C:/claude/faseA/ciclovita.ps1'
echo "cicli: $(date +%T)" | tee -a $O/fasi.txt
w "del C:\\claude\\faseA\\ciclovita.log 2>nul & schtasks /create /tn claude-cicli /tr \"powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\faseA\\ciclovita.ps1 -N 20\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn claude-cicli" > /dev/null
k=0
until cpw marietto@win11:'C:/claude/faseA/ciclovita.log' $O/ciclovita.log 2>/dev/null && /usr/bin/grep -q FINE $O/ciclovita.log; do
	pgrep -x bhyve >/dev/null || { echo "BHYVE USCITO durante i cicli"; break; }
	sleep 30; k=$((k+1)); [ $k -gt 120 ] && { echo "cicli non finiti in 1 h"; break; }
done
w "schtasks /delete /tn claude-cicli /f" > /dev/null
echo "fine cicli: $(date +%T)" | tee -a $O/fasi.txt
ps -H -o lwp,time,comm -p $P | /usr/bin/grep -i vcpu > $O/vcpu-dopo.txt
echo "vCPU (prima -> dopo):"; /usr/bin/paste $O/vcpu-prima.txt $O/vcpu-dopo.txt | awk '{print "   " $3, $4, $2, "->", $6}'
# 3. spegnimento ordinato
w "shutdown /s /t 0" >/dev/null 2>&1
i=0; while [ $i -lt 300 ] && pgrep -x bhyve >/dev/null; do sleep 2; i=$((i+2)); done
pgrep -x bhyve >/dev/null && echo "bhyve ANCORA VIVO dopo 300 s" || echo "spegnimento ordinato: bhyve uscito dopo $i s"
sleep 3
sudo -n pkill -TERM -f "win-lat.d|b1keep.d"; sleep 3
sudo -n pkill -KILL -f "vncviewer" 2>/dev/null
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
ctr > $O/ctr.dopo
sudo -n sysctl hw.vmm.vmx.vept_keep=0 hw.vmm.vmx.vept_verify_hpa=0 >/dev/null
echo "== carico:"; /usr/bin/grep -E "stress-ng rc|kernel rc|^real|ERRORE|io:|cicli|=== " $O/load.log | tail -15
echo "== cicli:"; tail -3 $O/ciclovita.log
echo "== orologio:"; tail -2 $O/clockmon.log
echo "== contatori:"; /usr/bin/paste $O/ctr.prima $O/ctr.dopo | awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-38s %d\n", $1, d}' | /usr/bin/grep -vE "_max_ns|diag_mem"
echo "   vept_shadow_pages dopo la distruzione: $(sysctl -n hw.vmm.vmx.vept_shadow_pages)"
echo "== massimi:"; /usr/bin/grep -E "_max_ns" $O/ctr.dopo
echo "== latenze L1 (coda):"; tail -25 $O/lat.txt
echo "OUTPUT $O"
