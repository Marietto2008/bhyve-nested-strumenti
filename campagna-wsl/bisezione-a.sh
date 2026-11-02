#!/bin/sh
# bisezione-a.sh -- Claude 02/11/2026. Configurazione A (QEMU -accel bhyve) ha BLOCCATO l'host (02/11 02:27, nessun
# dump). Bisezione dalla riga che ha FUNZIONATO il 18/10 (pc, BHYVE_UEFI.fd, 4G, smp 2, senza nested), una variabile
# alla volta, con l'immagine FreeBSD 15.2 preparata per WSL (parte in secondi, la seriale dice fin dove arriva).
# Uso (root): bisezione-a.sh <etichetta> [MACCHINA=pc|q35] [FW=bhyve|ovmf] [MEM=4G] [SMP=2] [NESTED=0|1] [SECONDI=90]
# Prova sopravvissuta = l'host risponde e il registro ha «FINE». Se l'host muore, il battito (fsync ogni secondo)
# dice QUANDO, e l'ultima riga di inizio dice QUALE prova.
set -u
PATH=/bin:/usr/bin:/sbin:/usr/sbin
ET=$1; shift
MACCHINA=pc FW=bhyve MEM=4G SMP=2 NESTED=0 SECONDI=90
for a in "$@"; do case $a in MACCHINA=*|FW=*|MEM=*|SMP=*|NESTED=*|SECONDI=*) eval "$a";; *) echo "argomento sconosciuto: $a"; exit 4;; esac; done
I=/home/marietto/claude-wsl2-immagini
L=$I/bisezione                      # disco INTERNO: deve sopravvivere a un reset
mkdir -p $L; D=$L/$(date +%Y%m%d-%H%M%S)-$ET; mkdir $D || exit 4
QEMU=/mnt/linuxulator2/vm/wsl2/fbsd/stage/current/bin/qemu-system-x86_64
QEMU_SHA=650a2bdec6f0fb61ec19066dcd13edd0b647267fd0cec2d0ce8974124b08859a
[ "$(sha256 -q $QEMU)" = "$QEMU_SHA" ] || { echo "QEMU diverso"; exit 4; }
[ -z "$(ls /dev/vmm 2>/dev/null)" ] || { echo "STOP: c'e' gia' una VM"; exit 4; }
ps -ax -o comm= | grep -qiE 'bhyve|qemu-system' && { echo "STOP: bhyve/qemu vivo"; exit 4; }
case $FW in
	bhyve) CODE=/usr/local/share/edk2-bhyve/BHYVE_UEFI.fd; VARS0=/mnt/linuxulator2/vm/qemu-vmm-build/freebsd-bhyve-uefi-vars.fd ;;
	ovmf)  CODE=/usr/local/share/qemu/edk2-x86_64-code.fd; VARS0=/usr/local/share/qemu/edk2-i386-vars.fd ;;
	*) echo "FW=bhyve|ovmf"; exit 4 ;;
esac
cp $VARS0 $D/vars.fd || exit 4
ACC="-accel bhyve"; [ $NESTED = 1 ] && ACC="-accel bhyve,nested=on"
# registro di inizio, SINCRONIZZATO prima di lanciare qualunque cosa
{ echo "INIZIO $(date '+%F %T') $ET MACCHINA=$MACCHINA FW=$FW MEM=$MEM SMP=$SMP NESTED=$NESTED SECONDI=$SECONDI"; } > $D/registro
cat $D/registro >> $L/STORIA; sync
# battito: un marcatore al secondo con fsync (dd conv=fsync), e sync di tutto
( while :; do date '+%T' | dd of=$D/battito conv=fsync status=none 2>/dev/null; sync; sleep 1; done ) &
B=$!
timeout -k 5 $SECONDI $QEMU -L /mnt/linuxulator2/vm/wsl2/fbsd/qemu-nested/pc-bios \
	$ACC -cpu max -machine $MACCHINA -m $MEM -smp $SMP -display none -monitor none \
	-serial file:$D/seriale.txt -snapshot -parallel none -no-reboot \
	-drive if=pflash,format=raw,readonly=on,file=$CODE \
	-drive if=pflash,format=raw,file=$D/vars.fd \
	-device virtio-blk-pci,drive=hd0 \
	-drive id=hd0,file=$I/fbsd152-wsl.raw,format=raw,if=none \
	-nic user,model=e1000 </dev/null >/dev/null 2>$D/stderr.log
rc=$?
kill $B 2>/dev/null
for v in $(ls /dev/vmm 2>/dev/null); do bhyvectl --destroy --vm=$v; done
seg=$(tr -d '\r' < $D/seriale.txt | strings | grep -aoE 'CLAUDE-FBSD-WSL[^$]*|Fatal trap[^$]*|panic:[^$]*|X64 Exception[^$]*' | head -1)
echo "FINE $(date '+%T') rc=$rc seriale: ${seg:-(nessun segnale, $(wc -c < $D/seriale.txt) byte)}" | tee -a $D/registro >> $L/STORIA
sync; cat $D/registro
