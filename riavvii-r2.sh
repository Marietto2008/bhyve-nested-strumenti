#!/bin/sh
# riavvii-r2.sh -- claude 15/11/2026 (diagnosi Fable 046 §5, passo 2): N riavvii di Windows (shutdown /r) nella stessa
# sessione QEMU (reset sul posto), con R2 (VM_RESET_INPLACE) caricato. Per ogni giro: reset visto nel registro di
# QEMU, nuovo avvio (SSH con LastBootUpTime cambiato), HypervisorPresent, ASSERT nuovi nella debugcon, triple fault,
# contatori del modulo. Si ferma al primo giro che fallisce. Gira come utente (sudo -n solo per leggere il registro).
#   sh riavvii-r2.sh <registro-qemu> <debugcon> [N]
set -u
L=$1; DC=$2; N=${3:-5}
PF=/home/marietto/.config/claude-wsl2/password-windows
W() { timeout 40 sshpass -f $PF ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 marietto@IP-WINDOWS-A "$@" 2>/dev/null | tr -d '\r'; }
# LastBootUpTime come numero (Ticks): niente virgolette dentro il comando (in sh '' non e' un apice, in zsh si')
avvio() { W 'powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.Ticks"' | tail -1; }
conta() { sudo -n /usr/bin/grep -c "$1" "$L"; }
ctr() { echo "reset_inplace=$(sysctl -n hw.vmm.reset_inplace) vmxon_doppio=$(sysctl -n hw.vmm.vmx.nested_inv_vmxon_doppio) reset_in_vmx=$(sysctl -n hw.vmm.vmx.nested_inv_reset_in_vmx) vpid01_viol=$(sysctl -n hw.vmm.vmx.vpid01_invariant_viol) coperto=$(sysctl -n hw.vmm.vmx.vpid01_coperto_da_invept 2>/dev/null) rete=$(sysctl -n hw.vmm.vmx.vpid01_rete_invvpid 2>/dev/null) vmcs_lib_attivo=$(sysctl -n hw.vmm.vmx.vmcs_liberato_attivo 2>/dev/null) vmcs_clear_altra=$(sysctl -n hw.vmm.vmx.vmcs_clear_altra_cpu 2>/dev/null) vmcs_pieno=$(sysctl -n hw.vmm.vmx.vmcs_attivi_pieno 2>/dev/null)"; }
dice() { echo "$(date '+%H:%M:%S') $*"; }
dice "inizio: $N riavvii; $(ctr); asserzioni nella debugcon finora: $(grep -c ASSERT "$DC")"
g=1
while [ $g -le $N ]; do
	k=0; a0=$(avvio); while [ -z "$a0" ] && [ $k -lt 6 ]; do sleep 10; k=$((k + 1)); a0=$(avvio); done	# primo CIM lento appena dopo l'avvio
	r0=$(conta 'reset del modulo'); tf0=$(conta 'triple fault'); as0=$(grep -c ASSERT "$DC")
	[ -n "$a0" ] || { dice "giro $g: Windows non risponde prima del riavvio: STOP"; exit 1; }
	W 'shutdown /r /t 3 /c "Claude: riavvio di prova R2"' >/dev/null; t0=$(date +%s)
	dice "giro $g: shutdown /r (avvio precedente $a0)"
	i=0; while [ "$(conta 'reset del modulo')" -le "$r0" ] && [ $i -lt 300 ]; do sleep 2; i=$((i + 2)); done
	[ "$(conta 'reset del modulo')" -gt "$r0" ] || { dice "giro $g: nessun reset in 300 s: STOP"; exit 1; }
	dice "giro $g: reset dopo $(( $(date +%s) - t0 ))s: $(sudo -n /usr/bin/grep 'reset del modulo' "$L" | tail -1)"
	i=0; a1=""
	while [ $i -lt 600 ]; do
		[ "$(conta 'triple fault')" -gt "$tf0" ] && { dice "giro $g: TRIPLE FAULT: STOP"; sudo -n /usr/bin/grep 'al triple fault' "$L" | tail -8; exit 1; }
		[ "$(grep -c ASSERT "$DC")" -gt "$as0" ] && { dice "giro $g: ASSERT nella debugcon: STOP"; grep ASSERT "$DC" | tail -3; exit 1; }
		a1=$(avvio); [ -n "$a1" ] && [ "$a1" != "$a0" ] && break
		sleep 10; i=$((i + 10))
	done
	[ -n "$a1" ] && [ "$a1" != "$a0" ] || { dice "giro $g: Windows non torna in 600 s: STOP; $(ctr)"; exit 1; }
	hv=$(W 'powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).HypervisorPresent"' | tail -1)
	dice "giro $g: OK, nuovo avvio $a1, al desktop dopo $(( $(date +%s) - t0 ))s, HypervisorPresent=$hv; $(ctr)"
	[ "$hv" = True ] || { dice "giro $g: Hyper-V NON attivo: STOP"; exit 1; }
	g=$((g + 1))
done
dice "WSL dopo l'ultimo riavvio:"
W 'wsl.exe -l -v' | tr -d '\000' | sed 's/^/  /'
W 'wsl.exe -e uname -sr' | tr -d '\000' | sed 's/^/  wsl uname: /'
dice "fine: $N/$N; $(ctr); AP al vettore di reset: $(conta 'vettore di reset'); triple fault: $(conta 'triple fault')"
