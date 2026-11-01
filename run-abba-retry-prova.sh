#!/bin/sh
# run-abba-retry-prova.sh -- Claude 27/10/2026, parere #85: UN braccio dell'ABBA a
# 2 VP retry 1 (A) contro retry 2 (B). Derivato da run-abba-prova.sh (24-25/10):
# la parte Windows (avvio, Windows fermo, WSL2, ext4 gapmem.sh, compilazione
# kbuild4.sh, spegnimento) e' INVARIATA. Cambia:
#   - unica variabile: R = vept_scan_retries (1|2). Tutto il resto FISSO e
#     riletto: vept_keep=1 vept_verify_hpa=1 vept_test_race=0
#     vept_scan_hold_keep=0 nested_shadow_vmcs=1 nested_shadow_verify=0
#     nested_fast_field_validate=0 nested_shadow_inject=0 nested_vpid_track=1
#     nested_vpid12_flush=0. Valori diversi dopo la scrittura -> nessuna VM;
#   - latenza del gestore INVEPT (abba-invept-lat.d) durante ext4 e
#     compilazione, file lat-04.txt / lat-05.txt (DTrace fermato con SIGTERM
#     e ASPETTATO);
#   - controlli ad ogni checkpoint: errori dello shadow e mismatch HPA ->
#     CORRETTEZZA; vCPU con VPID02 spento -> INCOMPLETA (non comparabile, #86);
#   - latenza chiusa e senza drop, misura del lavoro (kbuild-lavoro.sh) dopo la
#     compilazione, fuori dal tempo misurato: se mancano -> INCOMPLETA;
#   - mai bhyvectl --destroy se un processo bhyve/QEMU e' vivo o vm0:12 aperta;
#   - foto con frequenza delle CPU e affinita' del bhyve;
#   - NIENTE ripristino dei sysctl qui: lo fa (e lo verifica) l'orchestratore;
#   - permessi dei file copiati da Windows normalizzati (scp li crea 0605).
# Ultima riga: "OUTPUT <cartella> COMPLETA|INCOMPLETA <motivo>|CORRETTEZZA <motivo>|CONFIG <motivo>".
# Uso (da root, come l'orchestratore): env O=<cartella> R=<1|2> MOD=<A|B> sh run-abba-retry-prova.sh [D=480] [W=2]
D=${1:-480}; W=${2:-2}
B=/mnt/linuxulator2/vm/nested-work; N=$B/freebsd-nested/tools/nested; C=$B/faseA
O=${O:?cartella}; R=${R:?retry}; MOD=${MOD:?modalita}
mkdir -p "$O" || exit 1
H=IP-HOST
LAT=$N/abba-invept-lat.d
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000\r' | iconv -f CP850 -t UTF-8 2>/dev/null; }
cpw() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows scp -o StrictHostKeyChecking=no -o LogLevel=ERROR "$@"; }
task() {
	w "schtasks /create /tn $1 /tr \"$2\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn $1 >nul"
}
attendi_wsl() {
	k=0; while w "schtasks /query /tn claude-wsl /fo csv /nh" | /usr/bin/grep -qiE "esecuzione|running"; do sleep 5; k=$((k+1)); [ $k -gt 720 ] && break; done
}
wslrun() {
	printf '%s' "$1" > "$O/wsl-args.txt"
	cpw "$O/wsl-args.txt" marietto@win11:'C:/claude/wsl-args.txt'
	task claude-wsl "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1" > /dev/null
}
# processo della VM: NOME del programma che inizia con bhyve (anche bhyve-hlt-mirrorfix)
# e vm0:12 negli argomenti. Mai la sola riga di comando: un editor o una shell che
# NOMINA bhyve farebbe scattare la guardia a caso
vm_pid() { /bin/ps -ax -o pid= -o comm= -o args= | /usr/bin/awk '$2 ~ /^bhyve/ && / vm0:12/ {print $1; exit}'; }
vm_tutte() { /bin/ps -ax -o pid= -o comm= -o args= | /usr/bin/awk '$2 ~ /^(bhyve|qemu-system)/'; }
vm_viva() { [ -n "$(vm_pid)" ]; }
fase() { echo "FASE $1 $(date +%s.%N) $(date +%T)" | tee -a "$O/fasi.txt"; }
foto() {
	{
		echo "FOTO $1 $(date +%s.%N)"
		sysctl hw.vmm.vmx
		sysctl dev.cpu | /usr/bin/grep -E '\.freq:'
		p=$(vm_pid)
		[ -n "$p" ] && { ps -H -o lwp,time,comm -p "$p" 2>/dev/null | /usr/bin/grep vcpu; echo "cpuset: $(cpuset -g -p "$p" 2>&1 | tr '\n' ' ')"; }
		for c in 0 1; do echo "== vcpu $c"; bhyvectl --vm=vm0:12 --get-stats --cpu=$c 2>/dev/null; done
	} >> "$O/foto.txt" 2>&1
}
F0=$(sysctl -n hw.vmm.vmx.nested_sh_faults); E0=$(sysctl -n hw.vmm.vmx.nested_sh_entry_after_fault)
M0=$(sysctl -n hw.vmm.vmx.vept_keep_verify_mismatch); V0=$(sysctl -n hw.vmm.vmx.vpid02_off_vcpus)
STOP=""
controlla() {	# controlla <punto>: correttezza (parere #46 §4 e #85 §3.4)
	f=$(( $(sysctl -n hw.vmm.vmx.nested_sh_faults) - F0 ))
	e=$(( $(sysctl -n hw.vmm.vmx.nested_sh_entry_after_fault) - E0 ))
	mm=$(( $(sysctl -n hw.vmm.vmx.vept_keep_verify_mismatch) - M0 ))
	vo=$(( $(sysctl -n hw.vmm.vmx.vpid02_off_vcpus) - V0 ))
	vv=0; vi=0
	for c in 0 1; do
		s=$(bhyvectl --vm=vm0:12 --get-stats --cpu=$c 2>/dev/null)
		# END{print n+0}: un numero SEMPRE, anche se bhyvectl non risponde (VM uscita);
		# una sostituzione vuota renderebbe l'aritmetica un errore FATALE per sh
		vv=$(( vv + $(echo "$s" | awk -F'\t' '/VMfailValid restituiti/{n+=$NF} END{print n+0}') ))
		vi=$(( vi + $(echo "$s" | awk -F'\t' '/VMfailInvalid restituiti/{n+=$NF} END{print n+0}') ))
	done
	echo "CHECKPOINT $1 $(date +%T): errori shadow $f, ingressi dopo errore $e, mismatch HPA $mm, vCPU VPID02 spento $vo, VMfailValid $vv, VMfailInvalid $vi, bhyve $(vm_viva && echo vivo || echo USCITO)" | tee -a "$O/checkpoint.txt"
	if [ "$f" -ne 0 ] || [ "$e" -ne 0 ] || [ "$mm" -ne 0 ]; then
		echo "!!! CORRETTEZZA al punto $1: braccio FERMATO" | tee -a "$O/checkpoint.txt"
		sysctl hw.vmm.vmx | /usr/bin/grep -E "nested_sh_|vept_keep_verify|vpid02_off" >> "$O/checkpoint.txt"
		STOP="CORRETTEZZA $1"
	elif [ "$vo" -ne 0 ]; then
		# parere #86 §5: VPID02 spento = configurazione NON COMPARABILE, non un
		# errore di correttezza. (Un INVVPID02 che non cresce NON e' un criterio.)
		echo "!!! NON COMPARABILE al punto $1: VPID02 spento su $vo vCPU, braccio FERMATO" | tee -a "$O/checkpoint.txt"
		STOP="INCOMPLETA non comparabile: VPID02 spento su $vo vCPU ($1)"
	fi
}
lat_ok() {	# traccia chiusa (END scritto) e stderr di DTrace vuoto (nessun drop)
	/usr/bin/grep -q '== LATENZA CHIUSA ==' "$O/lat-$1.txt" 2>/dev/null && [ ! -s "$O/lat-$1.err" ]
}
pausa() {
	w "if exist C:\\claude\\guardia-pausa (echo GIA) else (echo pausa > C:\\claude\\guardia-pausa & echo CREATA)" | tail -1
}
LP=""
lat_avvia() {	# lat_avvia <fase>
	p=$(vm_pid)
	[ -n "$p" ] || { echo "latenza $1: VM non trovata" >> "$O/checkpoint.txt"; return; }
	dtrace -s "$LAT" "$p" -o "$O/lat-$1.txt" 2> "$O/lat-$1.err" &
	LP=$!
	k=0; until /usr/bin/grep -q '== LATENZA PRONTA ==' "$O/lat-$1.txt" 2>/dev/null; do sleep 0.5; k=$((k+1)); [ $k -gt 30 ] && break; done
}
lat_ferma() {	# SIGTERM (un dtrace in background ignora SIGINT) e attesa: END scritto
	[ -n "$LP" ] && { kill -TERM "$LP" 2>/dev/null; wait "$LP" 2>/dev/null; LP=""; }
}
fine() {	# fine <esito>
	lat_ferma
	kill $TS $VS 2>/dev/null
	[ -n "$O" ] && [ -d "$O" ] && /usr/bin/find "$O" -type f -exec chmod a+r {} +
	echo "OUTPUT $O $1"
	exit 0
}
# interruzione dall'orchestratore: DTrace chiuso e aspettato, Windows spento in
# modo ORDINATO via ssh (mai destroy di una VM viva), esito INCOMPLETA
interrotto() {
	echo "!!! INTERROTTO ($1) $(date +%T)" | tee -a "$O/checkpoint.txt"
	lat_ferma
	if vm_viva; then
		w "shutdown /s /t 0" >/dev/null 2>&1
		i=0; while [ $i -lt 300 ] && vm_viva; do sleep 2; i=$((i+2)); done
		vm_viva && echo "bhyve ANCORA VIVO dopo l'interruzione" | tee -a "$O/checkpoint.txt"
	fi
	fine "INCOMPLETA interrotto ($1)"
}
trap 'interrotto INT' INT
trap 'interrotto TERM' TERM
trap 'interrotto HUP' HUP
DISPLAY=:0; XAUTHORITY=/home/marietto/.Xauthority; export DISPLAY XAUTHORITY
vmstat -w 1 > "$O/vmstat.txt" &
VS=$!
python3 "$C/tsecho.py" 7123 "$O/tsecho.txt" &
TS=$!
mount | /usr/bin/grep -q "/mnt/da0p2" || mount -t ufs /dev/da0p2 /mnt/da0p2
sha256 /boot/kernel/vmm-restore.ko > "$O/modulo.txt"; kldstat | /usr/bin/grep vmm >> "$O/modulo.txt"
sha256 "$LAT" >> "$O/modulo.txt"
# isolamento: nessuna VM viva prima di creare la nostra
v=$(vm_tutte)
[ -n "$v" ] && { echo "$v" > "$O/vm-vive.txt"; fine "CONFIG processo VM vivo prima del braccio"; }
for n in /dev/vmm/*; do
	[ -e "$n" ] || continue
	a=$(fstat "$n" 2>/dev/null | sed 1d)
	[ -n "$a" ] && fine "CONFIG $n aperto"
done
# configurazione: scritta, poi RILETTA e confrontata
K="vept_keep vept_verify_hpa vept_test_race vept_scan_hold_keep vept_scan_retries nested_shadow_vmcs nested_shadow_verify nested_fast_field_validate nested_shadow_inject nested_vpid_track nested_vpid12_flush"
ATT="1 1 0 0 $R 1 0 0 0 1 0"
set -- $ATT
for k in $K; do sysctl hw.vmm.vmx.$k=$1 > /dev/null; shift; done
ORA=$(for k in $K; do sysctl -n hw.vmm.vmx.$k; done | tr '\n' ' ')
for k in $K; do sysctl hw.vmm.vmx.$k; done > "$O/configurazione.txt"
echo "modalita' $MOD: retry=$R (unica variabile), riletti: $ORA" | tee -a "$O/configurazione.txt"
[ "$ORA" = "$ATT " ] || fine "CONFIG sysctl riletti '$ORA' diversi da '$ATT'"
memoria() {
	{
		echo "== $1 $(date +%T)"
		sysctl -n vm.stats.vm.v_free_count vm.stats.vm.v_inactive_count vm.stats.vm.v_laundry_count hw.pagesize | tr '\n' ' '; echo "(pagine libere, inattive, laundry, pagesize)"
		swapinfo -k | tail -1
		vm_viva && w "powershell -NoProfile -Command \"Get-Process -Name vmmem* -ErrorAction SilentlyContinue | Select-Object ProcessName,WorkingSet64,PrivateMemorySize64 | Format-Table -AutoSize | Out-String\""
	} >> "$O/memoria.txt" 2>&1
}
memoria 00-prima
foto 00-prima
fase 01-avvio
vm_viva || bhyvectl --vm=vm0:12 --destroy 2>/dev/null	# solo un nodo residuo, mai una VM viva
sh "$N/12-Windows-11-vm12-senza-gpu" > "$O/script.log" 2>&1 &
i=0; while [ $i -lt 60 ] && [ ! -e /dev/vmm/vm0:12 ]; do sleep 1; i=$((i+1)); done
[ -e /dev/vmm/vm0:12 ] || fine "INCOMPLETA VM non creata"
i=0; until w "echo pronto" | /usr/bin/grep -q pronto; do sleep 10; i=$((i+10)); [ $i -gt 900 ] && break; vm_viva || break; done
echo "ssh pronto dopo circa $i s" | tee -a "$O/checkpoint.txt"
fase 01b-ssh-pronto
sleep 90
foto 01-avvio
{ echo "== Hyper-V e VBS"; w "powershell -NoProfile -Command \"(Get-CimInstance Win32_ComputerSystem).HypervisorPresent; (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors; Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\\Microsoft\\Windows\\DeviceGuard | Select-Object VirtualizationBasedSecurityStatus,SecurityServicesRunning | Format-List | Out-String\""; } > "$O/hyperv.txt" 2>&1
cat "$O/hyperv.txt"
controlla 01-avvio-Windows
if [ -z "$STOP" ]; then
	for f in gapmon.c memmon.c gapmem.sh kbuild4.sh kbuild-lavoro.sh; do cpw "$C/$f" marietto@win11:"C:/claude/faseA/$f"; done
	sh "$B/guardia-win.sh" aggiorna > "$O/guardia.txt" 2>&1
	sleep 30
	echo "guardia: $(pausa)" >> "$O/guardia.txt"
	fase 02-windows-senza-wsl
	wslrun "--shutdown"; sleep 20; attendi_wsl
	foto 02-inizio; sleep 120; foto 02-fine
	controlla 02-Windows-inattivo
fi
if [ -z "$STOP" ]; then
	fase 03-avvio-wsl
	w "del C:\\claude\\wsl-log.txt 2>nul" > /dev/null
	wslrun "-d Debian -u root -- sh -c 'uname -a; nproc; grep -c ^processor /proc/cpuinfo; uptime; dmesg | grep -i -E \"hv_|hyperv\" | head -5; echo WSL-OK' "
	sleep 20; attendi_wsl
	cpw marietto@win11:'C:/claude/wsl-log.txt' "$O/wsl-avvio.txt" 2>/dev/null
	cat "$O/wsl-avvio.txt"
	foto 03-wsl
	/usr/bin/grep -q WSL-OK "$O/wsl-avvio.txt" || { echo "!!! WSL non ha risposto" | tee -a "$O/checkpoint.txt"; STOP="INCOMPLETA WSL non ha risposto"; }
	controlla 03-avvio-WSL2
fi
if [ -z "$STOP" ]; then
	memoria 04-prima-ext4
	fase 04-ext4
	w "del C:\\claude\\faseA\\gapmem-A.log 2>nul" > /dev/null
	lat_avvia 04
	wslrun "-d Debian -u root -- bash -c 'tr -d \"\\\\r\" < /mnt/c/claude/faseA/gapmem.sh > /root/gapmem.sh; bash /root/gapmem.sh $D $H A $W'"
	r=0; k=0
	until /usr/bin/grep -q GAP-FINE "$O/gapmem-A.log" 2>/dev/null; do
		vm_viva || { echo "BHYVE USCITO"; break; }
		sleep 10; k=$((k+1)); [ $k -gt $(( (W * 150 + D + 900) / 10 )) ] && { echo "ext4 non finita"; break; }
		[ $(( $(sysctl -n hw.vmm.vmx.nested_sh_faults) - F0 )) -ne 0 ] && break
		[ $(( $(sysctl -n hw.vmm.vmx.vept_keep_verify_mismatch) - M0 )) -ne 0 ] && break
		cpw marietto@win11:"C:/claude/faseA/gapmem-A.log" "$O/gapmem-A.log" 2>/dev/null || continue
		if [ $r -eq 0 ] && /usr/bin/grep -q RISCALDAMENTO-FINE "$O/gapmem-A.log"; then r=1; foto 04-prova-inizio; fi
	done
	foto 04-fine
	lat_ferma
	for f in gapmem-A.log gapmem-gapmon-A.txt gapmem-memmon-A.txt gapmem-pre-A.txt gapmem-post-A.txt; do
		cpw marietto@win11:"C:/claude/faseA/$f" "$O/$f" 2>/dev/null
	done
	ne=$(/usr/bin/grep -c ERRORE "$O/gapmem-A.log" 2>/dev/null)
	echo "ext4: cicli $(/usr/bin/grep -c 'CICLO [0-9]* ok' "$O/gapmem-A.log" 2>/dev/null), ERRORI DI VERIFICA sha256 $ne, buchi $(/usr/bin/grep -c '^BUCO' "$O/gapmem-gapmon-A.txt" 2>/dev/null)" | tee -a "$O/checkpoint.txt"
	controlla 04-ext4
	[ -z "$STOP" ] && [ "${ne:-0}" -ne 0 ] && STOP="CORRETTEZZA errori sha256 ext4 $ne"
	[ -z "$STOP" ] && ! /usr/bin/grep -q GAP-FINE "$O/gapmem-A.log" 2>/dev/null && STOP="INCOMPLETA ext4 non finita"
	[ -z "$STOP" ] && ! lat_ok 04 && STOP="INCOMPLETA latenza ext4 mancante (traccia aperta o stderr di DTrace)"
fi
if [ -z "$STOP" ]; then
	memoria 05-prima-compilazione
	fase 05-compilazione
	w "del C:\\claude\\faseA\\kbuild.log 2>nul" > /dev/null
	lat_avvia 05
	wslrun "-d Debian -u root -- bash -c 'tr -d \"\\\\r\" < /mnt/c/claude/faseA/kbuild4.sh > /root/kbuild4.sh; bash /root/kbuild4.sh'"
	foto 05-inizio
	k=0
	until cpw marietto@win11:'C:/claude/faseA/kbuild.log' "$O/kbuild.log" 2>/dev/null && /usr/bin/grep -q KBUILD-FINE "$O/kbuild.log"; do
		vm_viva || { echo "BHYVE USCITO"; break; }
		[ $(( $(sysctl -n hw.vmm.vmx.nested_sh_faults) - F0 )) -ne 0 ] && break
		[ $(( $(sysctl -n hw.vmm.vmx.vept_keep_verify_mismatch) - M0 )) -ne 0 ] && break
		sleep 30; k=$((k+1)); [ $k -gt 240 ] && { echo "compilazione non finita in 2 h"; break; }
	done
	foto 05-fine
	lat_ferma
	/usr/bin/grep -E "^real|^user|^sys|kernel rc" "$O/kbuild.log" | tee -a "$O/checkpoint.txt"
	controlla 05-compilazione
	[ -z "$STOP" ] && ! /usr/bin/grep -q 'kernel rc=0' "$O/kbuild.log" 2>/dev/null && STOP="INCOMPLETA compilazione senza rc=0"
	[ -z "$STOP" ] && ! lat_ok 05 && STOP="INCOMPLETA latenza compilazione mancante (traccia aperta o stderr di DTrace)"
fi
if [ -z "$STOP" ]; then
	# parere #86 §2: quantita' e identita' del lavoro compilato, FUORI dal tempo misurato
	fase 05b-misura-lavoro
	w "del C:\\claude\\faseA\\kbuild-lavoro.txt 2>nul" > /dev/null
	wslrun "-d Debian -u root -- bash -c 'tr -d \"\\\\r\" < /mnt/c/claude/faseA/kbuild-lavoro.sh > /root/kbuild-lavoro.sh; bash /root/kbuild-lavoro.sh'"
	sleep 20; attendi_wsl
	k=0
	until cpw marietto@win11:'C:/claude/faseA/kbuild-lavoro.txt' "$O/kbuild-lavoro.txt" 2>/dev/null && /usr/bin/grep -q LAVORO-FINE "$O/kbuild-lavoro.txt"; do
		sleep 10; k=$((k+1)); [ $k -gt 30 ] && break
	done
	cat "$O/kbuild-lavoro.txt" 2>/dev/null | tee -a "$O/checkpoint.txt"
	/usr/bin/grep -q LAVORO-FINE "$O/kbuild-lavoro.txt" 2>/dev/null || STOP="INCOMPLETA misura del lavoro assente"
fi
memoria 06-prima-spegnimento
fase 06-spegnimento
sh "$B/guardia-win.sh" riprendi >> "$O/guardia.txt" 2>&1
w "schtasks /delete /tn claude-wsl /f" > /dev/null 2>&1
if vm_viva; then
	w "shutdown /s /t 0" >/dev/null 2>&1
	i=0; while [ $i -lt 300 ] && vm_viva; do sleep 2; i=$((i+2)); done
	vm_viva && echo "bhyve ANCORA VIVO" | tee -a "$O/checkpoint.txt" || echo "spegnimento ordinato dopo $i s" | tee -a "$O/checkpoint.txt"
fi
foto 06-fine
fase 07-fine
controlla 06-dopo-lo-spegnimento
sleep 3
vm_viva || bhyvectl --vm=vm0:12 --destroy 2>/dev/null	# solo se il bhyve e' uscito da solo
vm_viva && [ -z "$STOP" ] && STOP="INCOMPLETA bhyve ancora vivo dopo lo spegnimento"
case "$STOP" in
'') fine COMPLETA ;;
*) fine "$STOP" ;;
esac
