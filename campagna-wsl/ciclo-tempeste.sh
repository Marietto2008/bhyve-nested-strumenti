#!/bin/sh
# ciclo-tempeste.sh <n>: ripete la tempesta di timer (prova-vhd.sh, ro7d,
# claude-lag 1200) fino al primo panic o per <n> giri. La traccia DTrace delle
# iniezioni #PF si aggancia solo DOPO l'EarlyConfig di WSL (le sonde attive
# durante l'avvio fanno scadere CreateVm) e si stacca a fine giro. Con TRACCIA=0
# niente DTrace (le sonde su compose sopprimono il panic): si leggono i contatori
# e le righe nested_diag_pfinj del modulo diagpf2.
N=${1:-4}; P=/home/marietto/.config/claude-wsl2/password-windows
S=/tmp/claude-1001/-mnt-linuxulator2-freebsd-radxa-src/5c397449-f584-4e61-9504-47b7fe6ab862/scratchpad
LOG=/mnt/linuxulator2/vm/wsl2/fbsd/logs
TR=/mnt/linuxulator2/vm/wsl2/fbsd/campagna-wsl/iniezione-pf-campi.d
win() { timeout 40 sshpass -f $P ssh -o ConnectTimeout=20 marietto@IP-WINDOWS-B "$1" 2>/dev/null | tr -d '\r'; }
k=1
while [ $k -le $N ]; do
	T=$(date +%Y%m%d-%H%M%S); R=$LOG/ciclo-giro$k-$T.txt; DL=$LOG/ciclo-traccia$k-$T.txt
	echo "$(date +%T) giro $k: avvio ($R)"
	sh $S/prova-vhd.sh fbsd152-wsl-ro7d '-ComandoFile C:\claude\freebsd-tempesta.sh -BootTimeout 0 -Utente root' > $R 2>&1 &
	pv=$!
	until grep -q 'OPERAZIONE RIUSCITA' $R 2>/dev/null; do kill -0 $pv 2>/dev/null || break; sleep 5; done
	sleep 20
	t0=$(date +%s); agg=0
	while kill -0 $pv 2>/dev/null && [ $(( $(date +%s) - t0 )) -lt 300 ]; do
		r=$(win 'findstr /c:"EarlyConfig: hostname" /c:"ERROR_TIMEOUT" C:\claude\wsl-fbsd\console-wsl.txt C:\claude\prova-wsl-fbsd.log')
		if echo "$r" | grep -q ERROR_TIMEOUT; then echo "$(date +%T) giro $k: CreateVm ERROR_TIMEOUT"; break; fi
		if echo "$r" | grep -q EarlyConfig; then
			if [ "${TRACCIA:-1}" = 1 ]; then
				sudo -n daemon -o $DL dtrace -qs $TR; agg=1
				echo "$(date +%T) giro $k: EarlyConfig ricevuto, traccia agganciata ($DL)"
			else
				echo "$(date +%T) giro $k: EarlyConfig ricevuto (senza DTrace)"
			fi
			break
		fi
		sleep 5
	done
	wait $pv
	p=$(pgrep -f "dtrace -qs $TR"); [ -n "$p" ] && sudo -n kill -INT $p
	cp $S/wsl-fbsd152-wsl-ro7d.txt $LOG/ciclo-console$k-$T.txt
	ni=$( [ $agg = 1 ] && sudo -n grep -c INIEZIONE $DL || echo 0)
	ni="$ni; modulo: pfinj_all=$(sysctl -n hw.vmm.vmx.nested_diag_pfinj_all 2>/dev/null) pfinj_fetch=$(sysctl -n hw.vmm.vmx.nested_diag_pfinj_fetch 2>/dev/null)"
	if grep -q 'Fatal trap' $LOG/ciclo-console$k-$T.txt; then
		echo "$(date +%T) giro $k: PANIC (console $LOG/ciclo-console$k-$T.txt, iniezioni $ni)"
		exit 0
	fi
	echo "$(date +%T) giro $k: nessun panic, iniezioni catturate $ni"
	k=$((k + 1))
done
echo "$(date +%T) fine: nessun panic in $N giri"
