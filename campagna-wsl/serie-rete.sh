#!/bin/sh
# serie-rete.sh -- Claude 03/11/2026. Avvii ripetuti della configurazione A (vm0-13-qemu.sh) per catturare un avvio
# in cui la rete virtio-net non parte. Riuscito = la porta 22 di Windows risponde (SYN-ACK: RX e TX funzionano) entro
# 300 s; allora Windows si spegne via SSH e si riparte. Al PRIMO fallimento la serie si ferma e la VM resta accesa per
# l'analisi (QMP: qmp.py). Uso: [OPZ="opzioni di vm0-13-qemu.sh"] serie-rete.sh [numero di avvii, 6]
N=${1:-6}
OPZ=${OPZ:-"--qemu-sipi --nic-noeventidx --audio"}
C=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl
LOGD=/mnt/linuxulator2/vm/wsl2-freebsd-work/logs
PW=/home/marietto/.config/claude-wsl2/password-windows
H=IP-WINDOWS-B
porta22() { python3 -c "import socket,sys; s=socket.socket(); s.settimeout(3); sys.exit(0 if s.connect_ex(('$H',22))==0 else 1)"; }
acceso() { pgrep -f -- '-name vm0-13-qemu ' >/dev/null; }
i=1
while [ $i -le $N ]; do
	acceso && { echo "$(date +%T) QEMU gia' acceso: mi fermo"; exit 3; }
	L=$LOGD/vm0-13-avvio-$(date +%Y%m%d-%H%M%S).txt
	sudo -n daemon -o "$L" sh $C/vm0-13-qemu.sh $OPZ
	echo "$(date +%T) avvio $i: opzioni $OPZ"
	sleep 5
	t0=$(date +%s); ok=0
	while [ $(( $(date +%s) - t0 )) -lt 300 ]; do
		porta22 && { ok=1; break; }
		acceso || break
		sleep 3
	done
	dt=$(( $(date +%s) - t0 ))
	if [ $ok = 0 ]; then
		acceso && echo "$(date +%T) avvio $i: RETE ASSENTE dopo ${dt}s ($L), VM lasciata accesa" \
		       || echo "$(date +%T) avvio $i: QEMU USCITO dopo ${dt}s ($L)"
		exit 1
	fi
	echo "$(date +%T) avvio $i: rete OK a ${dt}s"
	sleep 30
	timeout 60 sshpass -f $PW ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o PubkeyAuthentication=no \
	    marietto@$H 'shutdown /s /t 0' >/dev/null 2>&1
	t1=$(date +%s)
	while acceso; do
		[ $(( $(date +%s) - t1 )) -gt 300 ] && { echo "$(date +%T) avvio $i: spegnimento bloccato"; exit 4; }
		sleep 3
	done
	sleep 5
	i=$((i + 1))
done
echo "$(date +%T) serie finita: $N avvii, rete sempre OK"
