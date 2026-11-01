#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-x2apic-linux.sh.non-conforme
echo "INERTE: run-x2apic-linux.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-x2apic-linux.sh.non-conforme" >&2; exit 4
# Claude 24/10/2026 -- parere #45 §6: il blocco di Windows con -x riguarda il nested? Matrice
# con un guest Linux SMP che non usa Hyper-V: Alpine virt 3.19 (ISO live, nessun disco),
# bhyve(8) di stage/current, UEFI, 2 vCPU, 1 GB:
#   D nested OFF x2APIC OFF   C nested OFF x2APIC ON   E nested ON x2APIC OFF   B2 nested ON x2APIC ON
# Ogni avvio dura S secondi; poi bhyvectl --get-stats per vCPU (uscite, HLT, ICR/IPI) e
# spegnimento forzato (ISO live: nessun dato da perdere). Console seriale su nmdm.
# Successo = il vCPU 1 registra uscite e HLT (l'AP e' partito); la console dice "smp:".
S=${1:-90}
B=/mnt/linuxulator2/vm/wsl2/linux
BHYVE=$B/stage/current/sbin/bhyve
ISO=/mnt/linuxulator2/vm/ISO/Linux/alpine-virt-3.19.0-x86_64.iso
O=$B/logs/x2apic-linux-$(date +%Y%m%d-%H%M); mkdir -p "$O"
kldstat -q -m nmdm || sudo -n kldload nmdm
for P in D C E B2; do
	case $P in
	D)  OPT="" ;;
	C)  OPT="-x" ;;
	E)  OPT="-o x86.nested_virt=true" ;;
	B2) OPT="-x -o x86.nested_virt=true" ;;
	esac
	VM=alpx2$P
	echo "######## $P: $OPT $(date +%T)" | tee -a "$O/riassunto.txt"
	sudo -n bhyvectl --vm=$VM --destroy 2>/dev/null
	( sudo -n cat /dev/nmdm7B > "$O/console-$P.txt" 2>/dev/null ) &
	CP=$!
	sudo -n "$BHYVE" -c 2 -m 1G -w -H -A $OPT \
	    -s 0,hostbridge -s 3,ahci-cd,"$ISO" -s 31,lpc -l com1,/dev/nmdm7A \
	    -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd $VM > "$O/bhyve-$P.log" 2>&1 &
	sleep "$S"
	for c in 0 1; do
		echo "== vcpu $c" >> "$O/stats-$P.txt"
		sudo -n bhyvectl --vm=$VM --get-stats --cpu=$c >> "$O/stats-$P.txt" 2>&1
		printf '  vcpu %s: %s uscite, %s HLT, %s IPI inviati\n' $c \
		    "$(sudo -n bhyvectl --vm=$VM --get-stats --cpu=$c 2>/dev/null | awk -F'\t' '/total number of vm exits/{print $NF}')" \
		    "$(sudo -n bhyvectl --vm=$VM --get-stats --cpu=$c 2>/dev/null | awk -F'\t' '/hlt was intercepted/{print $NF}')" \
		    "$(sudo -n bhyvectl --vm=$VM --get-stats --cpu=$c 2>/dev/null | awk -F'\t' '/ipis sent from vcpu/{print $NF}')" \
		    | tee -a "$O/riassunto.txt"
	done
	sudo -n bhyvectl --vm=$VM --force-poweroff 2>/dev/null
	i=0; while [ $i -lt 20 ] && pgrep -f "bhyve.*$VM" >/dev/null; do sleep 1; i=$((i+1)); done
	sudo -n bhyvectl --vm=$VM --destroy 2>/dev/null
	sudo -n pkill -f "cat /dev/nmdm7B"; kill $CP 2>/dev/null
	echo "  console: $(/usr/bin/grep -a -m3 -E 'smp: Brought up|x2apic|x2APIC' "$O/console-$P.txt" | tr '\n' ' ')" | tee -a "$O/riassunto.txt"
	sleep 3
done
echo "OUTPUT $O"
