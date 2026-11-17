#!/bin/sh
# reset-l2.sh -- claude 15/11/2026 (diagnosi Fable 050 §2, «prova mancante»): N reset di sistema da QMP (system_reset,
# senza spegnimento ordinato) mentre WSL lavora, cosi' al reset ci sono vCPU in L2. Per ogni giro: carico in WSL (4 cicli
# a vuoto per 10 min, da un'attivita' interattiva: via SSH wsl.exe da' «Accesso negato»), 45 s, system_reset, riga
# «N erano in L2» dal registro di QEMU, nuovo avvio con Hyper-V, contatori. Si ferma al primo giro che fallisce.
#   sh reset-l2.sh <registro-qemu> <debugcon> [N]
set -u
L=$1; DC=$2; N=${3:-3}
PF=/home/marietto/.config/claude-wsl2/password-windows
QMP=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/qmp.py
W() { timeout 40 sshpass -f $PF ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 marietto@IP-WINDOWS-A "$@" 2>/dev/null | tr -d '\r'; }
avvio() { W 'powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.Ticks"' | tail -1; }
conta() { sudo -n /usr/bin/grep -c "$1" "$L"; }
ctr() { echo "reset_inplace=$(sysctl -n hw.vmm.reset_inplace) vmxon_doppio=$(sysctl -n hw.vmm.vmx.nested_inv_vmxon_doppio) reset_in_vmx=$(sysctl -n hw.vmm.vmx.nested_inv_reset_in_vmx) vpid01_viol=$(sysctl -n hw.vmm.vmx.vpid01_invariant_viol) coperto=$(sysctl -n hw.vmm.vmx.vpid01_coperto_da_invept) rete=$(sysctl -n hw.vmm.vmx.vpid01_rete_invvpid) vmcs_lib_attivo=$(sysctl -n hw.vmm.vmx.vmcs_liberato_attivo) vmcs_clear_altra=$(sysctl -n hw.vmm.vmx.vmcs_clear_altra_cpu) vmcs_pieno=$(sysctl -n hw.vmm.vmx.vmcs_attivi_pieno)"; }
dice() { echo "$(date '+%H:%M:%S') $*"; }
dice "inizio: $N system_reset con WSL al lavoro; $(ctr)"
g=1
while [ $g -le $N ]; do
	k=0; a0=$(avvio); while [ -z "$a0" ] && [ $k -lt 6 ]; do sleep 10; k=$((k + 1)); a0=$(avvio); done
	[ -n "$a0" ] || { dice "giro $g: Windows non risponde: STOP"; exit 1; }
	# il comando sta in C:\claude\carico-wsl.cmd (strumenti/carico-wsl.cmd): dentro /tr le virgolette di cmd non reggono il ciclo
	W 'schtasks /create /tn ClaudeWslCarico /tr C:\claude\carico-wsl.cmd /sc once /sd 01/01/2020 /st 00:00 /it /f >nul && schtasks /run /tn ClaudeWslCarico' >/dev/null
	sleep 45
	st=$(W 'wsl.exe -l --running' | tr -d '\000' | tr '\n' ' ')
	dice "giro $g: carico WSL avviato (wsl -l --running via SSH: '${st:-?}')"
	r0=$(conta 'reset del modulo'); tf0=$(conta 'triple fault'); as0=$(grep -c ASSERT "$DC")
	sudo -n python3 $QMP system_reset >/dev/null; t0=$(date +%s)
	dice "giro $g: system_reset"
	i=0; while [ "$(conta 'reset del modulo')" -le "$r0" ] && [ $i -lt 60 ]; do sleep 1; i=$((i + 1)); done
	riga=$(sudo -n /usr/bin/grep 'reset del modulo\|VM_RESET_INPLACE' "$L" | tail -1)
	dice "giro $g: $riga"
	i=0; a1=""
	while [ $i -lt 900 ]; do
		[ "$(conta 'triple fault')" -gt "$tf0" ] && { dice "giro $g: TRIPLE FAULT: STOP"; sudo -n /usr/bin/grep 'al triple fault' "$L" | tail -8; exit 1; }
		[ "$(grep -c ASSERT "$DC")" -gt "$as0" ] && { dice "giro $g: ASSERT nella debugcon: STOP"; grep ASSERT "$DC" | tail -3; exit 1; }
		a1=$(avvio); [ -n "$a1" ] && [ "$a1" != "$a0" ] && break
		sleep 10; i=$((i + 10))
	done
	[ -n "$a1" ] && [ "$a1" != "$a0" ] || { dice "giro $g: Windows non torna in 900 s: STOP; $(ctr)"; exit 1; }
	hv=$(W 'powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).HypervisorPresent"' | tail -1)
	dice "giro $g: OK, al desktop dopo $(( $(date +%s) - t0 ))s, HypervisorPresent=$hv; $(ctr)"
	[ "$hv" = True ] || { dice "giro $g: Hyper-V NON attivo: STOP"; exit 1; }
	g=$((g + 1))
done
W 'schtasks /delete /tn ClaudeWslCarico /f' >/dev/null
dice "fine: $N/$N; $(ctr)"
