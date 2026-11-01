#!/bin/sh
# test-argv.sh -- Claude 29/10/2026 (#117 P0). Argv EFFETTIVE delle funzioni di mc-sistema.sh che cambiano lo stato.
# `sudo` e' ridefinito come funzione che REGISTRA gli argomenti (uno per [ ]) e non esegue nulla.
# 31/10/2026 (parere Opus sulla separazione): gira come utente collaudo; la guardia VERA scatterebbe (utente collaudo),
# quindi qui guardia_azione e' ridefinita per REGISTRARE la propria chiamata: ogni azione deve chiamarla PRIMA di sudo
# (atteso "G[...]"), e con la guardia che rifiuta sudo non deve partire (caso finale).
set -u
. /mnt/linuxulator2/vm/wsl2/fbsd/collaudo-preambolo.sh
D=$(cd "$(dirname "$0")" && pwd)
. "$D/mc-sistema.sh"
REG=""
GUARDIA_RC=0
guardia_azione() { REG="G"; return $GUARDIA_RC; }
sudo() { for a in "$@"; do REG="$REG[$a]"; done; return 0; }
P=0; F=0
atteso() { if [ "$REG" = "$1" ]; then P=$((P+1)); echo "  ok   $REG"; else F=$((F+1)); echo "  FAIL ottenuto $REG / atteso $1"; fi; }
# la sostituzione funziona davvero? (se sudo vero partisse, REG resterebbe vuoto)
s_freeze;                                  atteso "G[-n][/usr/sbin/devctl][freeze]"
s_thaw;                                    atteso "G[-n][/usr/sbin/devctl][thaw]"
s_kenv_set boot_safe YES;                  atteso "G[-n][/bin/kenv][boot_safe=YES]"
s_kenv_set devmatch_blocklist "if_cdce amdgpu"; atteso "G[-n][/bin/kenv][devmatch_blocklist=if_cdce amdgpu]"
s_kenv_set devmatch_blocklist "";          atteso "G[-n][/bin/kenv][devmatch_blocklist=]"
s_kenv_unset boot_safe;                    atteso "G[-n][/bin/kenv][-u][boot_safe]"
s_kldunload;                               atteso "G[-n][/sbin/kldunload][-n][vmm-restore.ko]"
s_kldload /boot/kernel/vmm-restore.ko;     atteso "G[-n][/sbin/kldload][/boot/kernel/vmm-restore.ko]"
s_vm_destroy vm2;                          atteso "G[-n][/usr/sbin/bhyvectl][--vm=vm2][--destroy]"
# kenv.c (r.39): divide al PRIMO '=' -> l'argv deve contenere 'nome=' esatto, mai 'nome+='
case "$(s_kenv_set devmatch_blocklist x; echo "$REG")" in *"+="*) F=$((F+1)); echo "  FAIL '+=' nell'argv";; *) P=$((P+1)); echo "  ok   nessun '+=' nell'argv";; esac
# la guardia che rifiuta: nessun sudo per nessuna azione
GUARDIA_RC=1
for a in s_freeze s_thaw "s_kenv_set boot_safe YES" "s_kenv_unset boot_safe" s_kldunload "s_kldload /boot/kernel/vmm-restore.ko" "s_vm_destroy vm2"; do
	REG=""; $a; r=$?
	[ "$REG" = G ] && [ $r != 0 ] && { P=$((P+1)); echo "  ok   guardia che rifiuta: $a non chiama sudo (rc $r)"; } || { F=$((F+1)); echo "  FAIL guardia che rifiuta: $a -> $REG rc $r"; }
done
# la guardia VERA, come utente collaudo, rifiuta (si ricarica guardia.sh)
. /mnt/linuxulator2/vm/wsl2/fbsd/caldo/guardia.sh
REG=""; m=$(s_freeze 2>&1); r=$?
[ $r != 0 ] && [ -z "$REG" ] && echo "$m" | grep -q 'GUARDIA: utente collaudo' && { P=$((P+1)); echo "  ok   guardia vera: s_freeze rifiutato come collaudo"; } || { F=$((F+1)); echo "  FAIL guardia vera: rc $r REG '$REG' $m"; }
echo "SUMMARY: $P ok, $F FAIL"
[ $F = 0 ]
