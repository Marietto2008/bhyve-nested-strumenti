#!/bin/sh
# prova-w1.sh -- claude 15/11/2026: prova A (Windows senza hypervisor, overlay 110842) con il modulo R2d. Sequenza:
# freddo, sul posto, freddo, sul posto. Per ogni avvio: esito (desktop / triple fault / tempo scaduto), processori,
# contatori CR. Si ferma al primo avvio che non arriva al desktop.
set -u
OV=/mnt/linuxulator2/vm/wsl2-freebsd-work/images/claude-wsl2-immagini/overlay/vm0-13-overlay-20261115-110842.qcow2
PF=/home/marietto/.config/claude-wsl2/password-windows
W() { timeout 60 sshpass -f $PF ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 marietto@IP-WINDOWS-A "$1" 2>/dev/null | tr -d '\r'; }
dice() { echo "$(date '+%H:%M:%S') $*"; }
ctr() { echo "cr0_pg=$(sysctl -n hw.vmm.vmx.cr0_pg_emulato) cr4=$(sysctl -n hw.vmm.vmx.cr4_inval_emulato) setreg=$(sysctl -n hw.vmm.vmx.cr_inval_setreg) viol=$(sysctl -n hw.vmm.vmx.vpid01_invariant_viol) vmcs_lib=$(sysctl -n hw.vmm.vmx.vmcs_liberato_attivo)"; }
avvio() { W 'powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.Ticks"' | tail -1; }
residuo() {
	V=$(sudo -n sh /mnt/linuxulator2/vm/nested-work/caldo/vmm-residuo.sh --verifica 2>&1 | tail -1)
	C=$(echo "$V" | sed -n 's/.*ctime=\([0-9]*\).*/\1/p'); M=$(echo "$V" | sed -n 's/.*memseg=\([0-9a-f]*\).*/\1/p')
	[ -n "$C" ] && sudo -n sh /mnt/linuxulator2/vm/nested-work/caldo/vmm-residuo.sh --distruggi vm2 $C $M >/dev/null 2>&1
}
aspetta() {	# $1 = avvio precedente (vuoto per il freddo); stampa l'esito
	i=0
	while [ $i -lt 90 ]; do
		sleep 10; i=$((i+1))
		sudo -n /usr/bin/grep -q 'triple fault' $L 2>/dev/null && { dice "$2: TRIPLE FAULT dopo $((i*10)) s; $(ctr)"; return 1; }
		a=$(avvio); [ -n "$a" ] && [ "$a" != "${1:-x}" ] && break
	done
	[ -n "$a" ] && [ "$a" != "${1:-x}" ] || { dice "$2: NON arriva al desktop in 900 s; $(ctr)"; return 1; }
	n=""; k=0; while [ -z "$n" ] && [ $k -lt 6 ]; do n=$(W 'powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors"' | tail -1); k=$((k+1)); [ -z "$n" ] && sleep 10; done
	dice "$2: DESKTOP dopo $((i*10)) s, processori $n; $(ctr)"
	ULTIMO=$a
}
freddo() {
	residuo
	T=$(date +%Y%m%d-%H%M%S); L=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs/vm0-13-avvio-$T.txt
	sudo -n env OVL_RIUSA=$OV daemon -o $L sh /mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/vm0-13-qemu.sh --qemu-sipi --overlay --audio --diag-reset
	dice "$1: avvio a freddo, registro $L"
	aspetta "" "$1"
}
sulposto() {
	r=$(W "shutdown /r /t 3 /c \"Claude: prova W1, riavvio sul posto\" && echo ACCETTATO" | tail -1)
	[ "$r" = ACCETTATO ] || { dice "$1: shutdown /r NON accettato ($r)"; return 1; }
	dice "$1: shutdown /r accettato"
	aspetta "$ULTIMO" "$1"
}
spegni() {
	r=$(W "shutdown /s /t 3 /c \"Claude: prova W1, spegnimento\" && echo ACCETTATO" | tail -1)
	dice "spegnimento: $r"; i=0; while ps -ax -o comm= | grep -q 'qemu-system' && [ $i -lt 100 ]; do sleep 3; i=$((i+1)); done
}
dice "inizio prova W1; $(ctr)"
freddo "avvio 1 (freddo)" || exit 1
sulposto "avvio 2 (sul posto)" || exit 1
spegni
freddo "avvio 3 (freddo)" || exit 1
sulposto "avvio 4 (sul posto)" || exit 1
dice "fine W1: 4/4; $(ctr)"
