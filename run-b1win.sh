#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-b1win.sh.non-conforme
echo "INERTE: run-b1win.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-b1win.sh.non-conforme" >&2; exit 4
# Claude 21/10/2026 -- B1 (parere #28), passo 7: Windows 11 + Hyper-V + WSL2 con
# hw.vmm.vmx.vept_keep=$1 (1) e vept_verify_hpa=$2 (1). Avvio, desktop, WSL2 con la
# compilazione del kernel (kb-ab.sh), spegnimento ordinato. Log in logs/b1win-*.
K=${1:-1}; V=${2:-1}; E=${3:-B1k${K}v${V}}; R=${4:-1}
B=/mnt/linuxulator2/vm/nested-work; N=$B/freebsd-nested/tools/nested; D=$B/dtrace
O=$B/logs/b1win-$E-$(date +%Y%m%d-%H%M); mkdir -p $O
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
ctr() { sysctl hw.vmm.vmx | /usr/bin/grep -E "vept_|nested_" | sed 's/^hw.vmm.vmx.//'; }
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
mount | grep -q "/mnt/da0p2" || sudo -n mount -t ufs /dev/da0p2 /mnt/da0p2
sudo -n sysctl hw.vmm.vmx.diag_efer=0 hw.vmm.vmx.vept_diag=0 hw.vmm.vmx.vept_keep=$K hw.vmm.vmx.vept_verify_hpa=$V hw.vmm.vmx.vept_scan_retries=$R hw.vmm.vmx.vept_test_race=0 hw.vmm.vmx.vept_scan_max_ns=0 hw.vmm.vmx.vept_t_scan_max_ns=0 hw.vmm.vmx.vept_t_partial_max_ns=0 hw.vmm.vmx.vept_t_full_max_ns=0 hw.vmm.vmx.nested_invept_ns_max=0 hw.vmm.vmx.vept_t_verify_max_ns=0 >/dev/null
ctr > $O/ctr.prima
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
sudo -n dtrace -s $D/b1keep.d -o $O/b1keep.txt 2>$O/b1keep.err &
sudo -n dtrace -s $D/b1rip.d -o $O/b1rip.txt 2>$O/b1rip.err &
sleep 3
sudo -n sh $N/${VMS:-12-Windows-11-vm12-senza-gpu} > $O/script.log 2>&1 &
i=0; while [ $i -lt 60 ]; do [ -e /dev/vmm/vm0:12 ] && break; sleep 1; i=$((i+1)); done
[ -e /dev/vmm/vm0:12 ] || { echo "VM NON creata"; exit 1; }
# TOLTO 23/10: xdotool windowminimize su TigerVNC fa crollare openbox (client_calc_layer), vedi memoria
T0=$(date +%s)
i=0; until w "echo pronto" | grep -q pronto; do
	pgrep -x bhyve >/dev/null || { echo "BHYVE USCITO durante l'avvio"; break; }
	sleep 10; i=$((i+10)); [ $i -gt 900 ] && { echo "SSH non risponde dopo 900 s"; break; }
done
echo "ssh pronto dopo $(( $(date +%s) - T0 )) s" | tee $O/avvio.txt
# task rimasti da prove vecchie: claude-vita fa 20 volte wsl --shutdown (la build del 21/10 23:59)
w "schtasks /delete /tn claude-vita /f & schtasks /delete /tn claude-clk /f" > $O/task-vecchi.txt 2>&1
# memoria della shadow ogni minuto
( while pgrep -x bhyve >/dev/null; do echo "$(date +%T) $(sysctl -n hw.vmm.vmx.vept_shadow_pages)"; sleep 60; done ) > $O/shadow-pages.txt &
sleep 90			# il desktop e i servizi finiscono di partire
w "powershell -NoProfile -Command \"(Get-CimInstance Win32_ComputerSystem | Select-Object NumberOfProcessors,NumberOfLogicalProcessors | Format-List | Out-String).Trim()\"" > $O/topologia.txt 2>&1
P=$(pgrep -x bhyve); ps -H -o lwp,time,comm -p $P | /usr/bin/grep -i vcpu > $O/vcpu-prima.txt
pgrep -x bhyve >/dev/null && sh $B/faseA/kb-ab.sh $E ${KBS:-kbuild.sh} > $O/kb.txt 2>&1
ps -H -o lwp,time,comm -p $P | /usr/bin/grep -i vcpu > $O/vcpu-dopo.txt
echo "topologia: $(tr -s ' \r\n' ' ' < $O/topologia.txt)"; echo "vCPU (prima -> dopo):"; /usr/bin/paste $O/vcpu-prima.txt $O/vcpu-dopo.txt | awk '{print "   " $3, $4, $2, "->", $6}'
cat $O/kb.txt
ctr > $O/ctr.dopo-build
# spegnimento ordinato
w "shutdown /s /t 0" >/dev/null 2>&1
i=0; while [ $i -lt 300 ] && pgrep -x bhyve >/dev/null; do sleep 2; i=$((i+2)); done
pgrep -x bhyve >/dev/null && echo "bhyve ANCORA VIVO dopo 300 s" || echo "spegnimento ordinato: bhyve uscito dopo $i s"
sleep 3
sudo -n pkill -INT -x dtrace; sleep 5; sudo -n pkill -TERM -f "b1keep.d|b1rip.d"; sleep 3
sudo -n pkill -KILL -f "vncviewer" 2>/dev/null
sudo -n bhyvectl --vm=vm0:12 --destroy 2>/dev/null
ctr > $O/ctr.dopo
sudo -n sysctl hw.vmm.vmx.vept_keep=0 hw.vmm.vmx.vept_verify_hpa=0 >/dev/null
echo "contatori:"; /usr/bin/paste $O/ctr.prima $O/ctr.dopo | awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-34s %+d\n", $1, d}'
sed -n '/##### totale/,$p' $O/b1keep.txt | head -40
dmesg | grep -i "B1 verifica\|panic\|nested:" | tail -5
echo "OUTPUT $O"
