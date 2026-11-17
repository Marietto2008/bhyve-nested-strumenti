#!/bin/sh
# tara-ritmo-lapic.sh giri-file pattern-ciclo -- Claude 13/11/2026: attende «tempesta partita» nel file dei giri, poi
# misura dall'host per 3 finestre da 20 s il ritmo delle uscite 48 riflesse sulla pagina LAPIC (scritture 0xd82,
# letture 0xd81) e degli episodi E0. Serve a rendere UGUALE il carico Linux e FreeBSD sotto QEMU-WHPX.
G=$1
n0=$(/usr/bin/grep -c 'tempesta partita' $G)
until [ $(/usr/bin/grep -c 'tempesta partita' $G) -gt $n0 ]; do pgrep -qf "$2" || { echo ciclo morto; exit 1; }; sleep 5; done
sleep 30
q() { sysctl -n hw.vmm.vmx.nested_diag_q48 | /usr/bin/grep 'pagina LAPIC' | tr ' ' '\n' | awk -F: -v k=$1 '$1==k {print $2}'; }
e() { sysctl -n hw.vmm.vmx.nested_diag_pfrec_e0; }
for f in 1 2 3; do
	w0=$(q 0xd82); r0=$(q 0xd81); e0=$(e); sleep 20; w1=$(q 0xd82); r1=$(q 0xd81); e1=$(e)
	echo "$(date +%T) finestra $f: scritture LAPIC $(( (w1 - w0) / 20 ))/s, letture $(( (r1 - r0) / 20 ))/s, E0 $(( (e1 - e0) / 20 ))/s"
done
