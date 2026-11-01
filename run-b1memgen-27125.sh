#!/bin/sh
# INERTE (31/10/2026, parere Opus sulla separazione par. 6): azioni sull'host senza guardia_azione. Originale: run-b1memgen-27125.sh.non-conforme
echo "INERTE: run-b1memgen-27125.sh ha azioni sull'host senza guardia (controllo-azioni.sh). Va adattato e riabilitato uno per volta; originale in run-b1memgen-27125.sh.non-conforme" >&2; exit 4
# run-b1memgen-27125.sh -- Claude 26/10/2026: SOLA b1_memgen (1 VM QEMU), ripetizione
# dopo la suite-1, dove l'iniezione memgen arrivo' a test finito. Base: suite B1 sul modulo
# attuale 27125f004917 con vept_keep=1, vept_verify_hpa=1, vept_scan_retries=1.
# SCOPE: 1 test = 1 VM QEMU (nome "vm2", la VM dei kvm-unit-tests, ricreata da
# QEMU a ogni test). Da lanciare SOLO con l'assenso dell'utente per QUESTA suite.
# Nessun retry, nessuna corsa successiva automatica. Ripristina i sysctl iniziali.
W=/mnt/linuxulator2/vm/wsl2/linux
T=$W/freebsd-nested/tools/nested
L=$T/kut-b1keep-27125.list
MOD_SHA=149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9
FLAT=$W/kut/vmxc-plain.flat
FLAT_SHA=848b0410e94ca86be1b06a7288f6c80c1de8f3e90eec4a2872e49afbade5c7a5
EV=$W/evidenze-b1keep-27125/memgen-2
mkdir -p $EV || exit 1
[ -e $EV/riepilogo.txt ] && { echo "STOP: suite gia' fatta ($EV)"; exit 1; }
cd $W || exit 1

S="hw.vmm.vmx.vept_keep hw.vmm.vmx.vept_verify_hpa hw.vmm.vmx.vept_scan_retries hw.vmm.vmx.vept_test_race hw.vmm.vmx.vept_diag hw.vmm.nested_memgen_inject"
PRIMA=$(/sbin/sysctl -n $S | /usr/bin/tr '\n' ' ')
ripristina() {
	set -- $PRIMA
	sudo -n /sbin/sysctl hw.vmm.vmx.vept_keep=$1 hw.vmm.vmx.vept_verify_hpa=$2 \
	    hw.vmm.vmx.vept_scan_retries=$3 hw.vmm.vmx.vept_test_race=$4 \
	    hw.vmm.vmx.vept_diag=$5 hw.vmm.nested_memgen_inject=$6 >/dev/null
}
ferma() { echo "STOP: $*"; ripristina; exit 1; }

echo "=== controlli a freddo ==="
[ "$(/sbin/sha256 -q /boot/kernel/vmm-restore.ko)" = "$MOD_SHA" ] || ferma "modulo diverso da 27125f004917"
[ "$(/sbin/sha256 -q $FLAT)" = "$FLAT_SHA" ] || ferma "vmxc-plain.flat diverso"
[ "$(/sbin/sysctl -n hw.vmm.vmx.nested_diag58)" = "0" ] || ferma "nested_diag58 acceso"
vivi=$(sudo -n /bin/ps axww -o pid,ppid,user,command | /usr/bin/grep -iE 'bhyve|qemu-system' | /usr/bin/grep -v grep)
[ -n "$vivi" ] && { echo "$vivi"; ferma "processo VM vivo"; }
for v in /dev/vmm/*; do
	[ -e "$v" ] || continue
	a=$(sudo -n /usr/bin/fstat "$v" 2>/dev/null | /usr/bin/sed 1d)
	[ -n "$a" ] && { echo "$a"; ferma "$v aperto da un processo"; }
done
/usr/bin/cc -Wall -o $EV/memgen-bump $T/memgen-bump.c || ferma "build memgen-bump"
{
	echo "modulo $MOD_SHA"; echo "flat $FLAT_SHA"; echo "lista $(/sbin/sha256 -q $L)"
	echo "script $(/sbin/sha256 -q $0)"; echo "sysctl iniziali: $PRIMA"
	sudo -n /usr/sbin/cpucontrol -m 0x8b /dev/cpuctl6
	/sbin/sysctl kern.osrelease; /bin/ls -la /dev/vmm
} > $EV/baseline.txt 2>&1

echo "=== configurazione (impostata E riletta) ==="
sudo -n /sbin/sysctl hw.vmm.vmx.vept_keep=1 hw.vmm.vmx.vept_verify_hpa=1 hw.vmm.vmx.vept_scan_retries=1 \
    hw.vmm.vmx.vept_test_race=0 hw.vmm.vmx.vept_diag=0 hw.vmm.nested_memgen_inject=0 >/dev/null || ferma "sysctl"
[ "$(/sbin/sysctl -n hw.vmm.vmx.vept_keep)" = 1 ] && [ "$(/sbin/sysctl -n hw.vmm.vmx.vept_verify_hpa)" = 1 ] && \
    [ "$(/sbin/sysctl -n hw.vmm.vmx.vept_scan_retries)" = 1 ] || ferma "sysctl non applicati"
/sbin/sysctl $S | /usr/bin/tee $EV/configurazione.txt

ctr() { /sbin/sysctl hw.vmm.vmx | /usr/bin/grep -E '^hw.vmm.vmx.(vept_keep_|vept_leaves_zapped_|vept_memgen_|vept_stale_root_enters|vept_keep_verify_|vept_scan_|vept_invept_)' | /usr/bin/sed 's/^hw.vmm.vmx.//'; }
delta() { /usr/bin/paste $1 $2 | /usr/bin/awk -F'[:\t ]+' '{d=$4-$2; if (d!=0) printf "   %-38s %+d\n", $1, d}'; }
val() { /usr/bin/paste $1 $2 | /usr/bin/awk -F'[:\t ]+' -v k=$3 '$1==k {print $4-$2}'; }

esito=0
for nome in b1_memgen; do
	/usr/bin/grep "^$nome " $L > $EV/$nome.list
	ctr > $EV/$nome.prima
	if [ $nome = b1_memgen ]; then
		sudo -n /sbin/sysctl hw.vmm.nested_memgen_inject=1 >/dev/null
		sudo -n env TEST_CPUS=6 /bin/sh $W/kutvpid/kut-run.sh --nested $EV/$nome.list > $EV/$nome.kut 2>&1 &
		KP=$!
		i=0
		while [ $i -lt 120 ]; do
			# kut-run scrive l'uscita di QEMU in .serial.raw MENTRE gira; il
			# .serial filtrato nasce solo a VM terminata (corretto 26/10 sera:
			# prima si guardava il .serial e l'iniezione arrivava a test finito)
			s=$(/bin/ls -t $W/logs/kut-*-b1_memgen.serial.raw 2>/dev/null | /usr/bin/head -1)
			[ -n "$s" ] && [ $s -nt $EV/$nome.prima ] && /usr/bin/grep -q "B1MG: pronto" $s && break
			sleep 1; i=$((i + 1))
		done
		sleep 3
		echo "iniezione memgen: $(sudo -n $EV/memgen-bump vm2 2>&1)" | /usr/bin/tee $EV/$nome.bump
		wait $KP
		sudo -n /sbin/sysctl hw.vmm.nested_memgen_inject=0 >/dev/null
	else
		sudo -n env TEST_CPUS=6 /bin/sh $W/kutvpid/kut-run.sh --nested $EV/$nome.list > $EV/$nome.kut 2>&1
	fi
	ctr > $EV/$nome.dopo
	s=$(/bin/ls -t $W/logs/kut-*-$nome.serial 2>/dev/null | /usr/bin/head -1)
	/bin/cp -n "$s" $EV/$nome.serial 2>/dev/null
	ver=$(/usr/bin/grep -E "^  $nome " $EV/$nome.kut | /usr/bin/awk '{print $2}')
	nfail=$(/usr/bin/grep -c '^FAIL' $EV/$nome.serial 2>/dev/null)
	part=$(val $EV/$nome.prima $EV/$nome.dopo vept_keep_partial_invepts); full=$(val $EV/$nome.prima $EV/$nome.dopo vept_keep_full_fallbacks)
	if [ "$ver" = PASS ] && [ "${nfail:-1}" = 0 ]; then funz=PASS; else funz="FAIL($ver,fail=$nfail)"; esito=1; fi
	if [ "${part:-0}" -gt 0 ]; then perc=ESERCITATO; else perc="NON_ESERCITATO"; fi
	if [ $nome = b1_memgen ]; then
		mg=$(val $EV/$nome.prima $EV/$nome.dopo vept_memgen_changes_detected)
		if [ "${mg:-0}" -gt 0 ]; then perc="$perc PERCORSO_MEMGEN=ESERCITATO(${mg})"; else perc="$perc PERCORSO_MEMGEN=NON_ESERCITATO"; esito=1; fi
	fi
	echo "== $nome: FUNZIONALE=$funz PERCORSO_PARZIALE=$perc (partial ${part:-0}, full ${full:-0})" | /usr/bin/tee -a $EV/riepilogo.txt
	/usr/bin/grep -E '^(PASS|FAIL|SUMMARY)' $EV/$nome.serial | /usr/bin/sed 's/^/   /' | /usr/bin/tail -15
	delta $EV/$nome.prima $EV/$nome.dopo | /usr/bin/tee $EV/$nome.delta
done

ripristina
echo "sysctl ripristinati: $(/sbin/sysctl -n $S | /usr/bin/tr '\n' ' ')" | /usr/bin/tee -a $EV/riepilogo.txt
/bin/ls -la /dev/vmm | /usr/bin/tee -a $EV/riepilogo.txt
/sbin/sha256 -r $EV/* > $EV/SHA256SUMS 2>/dev/null
echo "SUITE: $( [ $esito = 0 ] && echo 'tutti i test PASS' || echo 'ALMENO UN FAIL' ) -- nessuna corsa successiva automatica"
