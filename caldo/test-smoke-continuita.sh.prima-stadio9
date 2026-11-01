#!/bin/sh
# test-smoke-continuita.sh -- Claude 30/10/2026, parere #152 §4. Collaudo della modalita' --continuita di
# smoke-modulo.sh su COPIE della sessione D (mai sull'originale) e su copie del diario di modulo-caldo. Legge l'host
# (sysctl, kldstat, dtrace -l: sola lettura) col modulo RIPFIX r5 caricato e FTL=1/VMU=0 dopo D.
# Uso: test-smoke-continuita.sh <cartella nuova su ZFS> <sessione D>
set -u
C=/mnt/linuxulator2/vm/wsl2/linux/caldo
O=${1:?cartella}; D=${2:?sessione D}
case "$O" in /mnt/linuxulator2/vm/wsl2/linux/*) ;; *) echo "fuori dal workspace ZFS"; exit 2;; esac
[ -e "$O" ] && { echo "$O esiste gia'"; exit 2; }
mkdir -p "$O" || exit 2
DIA=/mnt/linuxulator2/vm/wsl2/linux/logs/modulo-caldo/diario.txt
nf=0; nok=0
ok() { nok=$((nok+1)); echo "  ok      $*"; }
no() { nf=$((nf+1)); echo "  ERRATO  $*"; }
copia() {	# copia dei soli file del SHA256SUMS della sessione (l'originale resta intatta; i socket del collaudo no)
	mkdir -p "$O/$1/drv" && cp -p "$D/SHA256SUMS" "$O/$1/" && (cd "$D" && cut -c66- SHA256SUMS | while read f; do cp -p "$f" "$O/$1/$f"; done)
}
risomma() { (cd "$O/$1" && cut -c66- SHA256SUMS | xargs sha256 -r > SHA256SUMS.n && cat SHA256SUMS.n >| SHA256SUMS); }
caso() {	# caso <nome> <sessione> <diario> <frammento atteso> [assente]
	SM_DIARIO=$3 sh $C/smoke-modulo.sh ripfix-nested --continuita "$2" > "$O/$1.out" 2>&1
	if grep -qF -- "$4" "$O/$1.out"; then ok "$1: '$4'"; else no "$1: manca '$4' ($(grep -E 'continuita|fatal_latches|unemul' $O/$1.out | head -2 | tr '\n' ' '))"; fi
}
echo "S1: sessione D vera, diario vero"
caso s1 "$D" "$DIA" "hw.vmm.fatal_latches = 1 (= valore finale della sessione di riferimento)"
grep -q "sessione di riferimento integra" "$O/s1.out" && ok "s1: sessione integra" || no "s1: integrita'"
grep -q "ERRATO" "$O/s1.out" && [ "$(grep -c ERRATO $O/s1.out)" = "$(grep -c 'ERRATO  CONTROLLO VMM' $O/s1.out)" ] && ok "s1: l'unico eventuale errore e' il CONTROLLO VMM" || \
    { grep -q ERRATO "$O/s1.out" || ok "s1: nessun errore"; }
echo "S2: mutanti della sessione"
copia m1; printf 'x\n' >> "$O/m1/drv/seriale.txt"
caso m1 "$O/m1" "$DIA" "diverso dal suo SHA256SUMS"
copia m2; sed -i '' 's/^FTL after=1$/FTL after=2/' "$O/m2/drv/combinato.txt"; risomma m2
caso m2 "$O/m2" "$DIA" "la sessione di riferimento chiudeva a 2: cambiato senza esperimento autorizzato"
copia m3; sed -i '' 's/^modulo caricato: \(.*\) 7bdd/modulo caricato: \1 0bdd/' "$O/m3/manifest.txt"; risomma m3
caso m3 "$O/m3" "$DIA" "il manifest non registra il modulo"
copia m4; sed -i '' '/^vm2 dopo: creata /d' "$O/m4/manifest.txt"; risomma m4
caso m4 "$O/m4" "$DIA" "non registra l'avvio della sessione"
copia m5; sed -i '' '/^VMU after=/d' "$O/m5/drv/combinato.txt"; risomma m5
caso m5 "$O/m5" "$DIA" "la sessione non registra FTL/VMU"
caso m6 "$O/non-esiste" "$DIA" "continuita' non dimostrabile"
echo "S3: mutanti del diario di modulo-caldo"
cp "$DIA" "$O/d1.txt"; echo "2026-10-30 23:59:00 === ESEGUO: da /boot/kernel/vmm-restore.ko a /mnt/linuxulator2/vm/wsl2/linux/logs/ripfix-congelato-20261030-r5/nested/vmm-restore.ko ===" >> "$O/d1.txt"
caso d1 "$D" "$O/d1.txt" "dopo l'avvio della sessione"
cp "$DIA" "$O/d2.txt"; echo "2026-10-30 17:30:00 === ESEGUO: da /mnt/linuxulator2/vm/wsl2/linux/logs/ripfix-congelato-20261030-r5/nested/vmm-restore.ko a /boot/kernel/vmm-restore.ko ===" >> "$O/d2.txt"
caso d2 "$D" "$O/d2.txt" "l'ultimo scambio del diario non porta a"
: >| "$O/d3.txt"; caso d3 "$D" "$O/d3.txt" "diario di modulo-caldo senza scambi"
echo "S4: la modalita' C1 resta quella del primo caricamento"
sh $C/smoke-modulo.sh ripfix-nested > "$O/c1.out" 2>&1
grep -q "C1 esige 0: dopo un test fatale usare --continuita" "$O/c1.out" && ok "c1: FTL=1 rifiutato da C1 con l'indicazione giusta" || no "c1"
sh $C/smoke-modulo.sh ripfix-nested --continuita > "$O/u1.out" 2>&1; [ $? = 4 ] && grep -q '^uso:' "$O/u1.out" && ok "u1: --continuita senza sessione rifiutato" || no "u1"
sh $C/smoke-modulo.sh originale --continuita "$D" > "$O/u2.out" 2>&1; [ $? = 4 ] && grep -q '^uso:' "$O/u2.out" && ok "u2: --continuita solo per ripfix-nested" || no "u2"
cmp -s "$D/SHA256SUMS" "$D/SHA256SUMS" && (cd "$D" && cut -c66- SHA256SUMS | xargs sha256 -r | cmp -s - SHA256SUMS) && ok "la sessione D originale e' intatta" || no "sessione D alterata!"
echo "SUMMARY: $nok ok, $nf errati"
[ $nf = 0 ]
