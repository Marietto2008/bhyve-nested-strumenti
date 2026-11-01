#!/bin/sh
# run.sh -- Claude 31/10/2026, stadio 10. Uso: run.sh <albero sorgente> <cartella di uscita nuova>
set -eu
. /mnt/linuxulator2/vm/wsl2/fbsd/collaudo-preambolo.sh	# 31/10/2026 (parere Opus sull'incidente): solo utente collaudo, sudo irraggiungibile
D=$(cd "$(dirname "$0")" && pwd); T=$1; O=$2
[ -e "$O" ] && { echo "$O esiste"; exit 2; }
mkdir -p "$O"
/usr/local/bin/python3 "$D/estrai.py" "$T/sys/amd64/vmm/vmm_instruction_emul.c" vie_alignment_check vie_canonical_check \
    vie_size2mask vie_calculate_gla get_gla emulate_stack_op > "$O/estratte.c"
cp "$D/stub.h" "$D/banco.c" "$O/"
cc -O0 -g -Wall -Wno-unused-function -Wno-uninitialized -ftrivial-auto-var-init=pattern -I "$O" -o "$O/banco" "$O/banco.c"
"$O/banco"
