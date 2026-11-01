# collaudo-preambolo.sh -- Claude 31/10/2026, parere Opus sull'incidente, par. 3.1 e 3.3. Preambolo COMUNE di ogni
# suite e di ogni mutante: si carica come prima cosa (`. /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh`).
#   - le suite girano SOLO come utente `collaudo` (nessuna voce in sudoers): da Claude Code `sudo -u collaudo sh ...`
#   - PATH senza /usr/local/bin: `sudo` non e' nemmeno raggiungibile
#   - l'uscita delle suite sta in /mnt/linuxulator2/vm/nested-work/collaudi (di collaudo)
# collaudo-bin contiene SOLO i collegamenti agli strumenti di /usr/local/bin che servono ai collaudi (python3), mai sudo
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/mnt/linuxulator2/vm/nested-work/collaudo-bin; export PATH
umask 022
if [ "$(/usr/bin/id -un)" != collaudo ]; then echo "STOP: le suite girano solo come utente collaudo (sudo -u collaudo sh $0 ...)"; exit 2; fi
if command -v sudo >/dev/null 2>&1; then echo "STOP: sudo raggiungibile dal collaudo"; exit 2; fi
if ! command -v python3 >/dev/null 2>&1; then echo "STOP: python3 non raggiungibile (collaudo-bin)"; exit 2; fi
COLLAUDI=/mnt/linuxulator2/vm/nested-work/collaudi
# parere Opus sulla separazione par. 6: collaudo NON deve poter scrivere fuori da collaudi/. Qui il controllo RAPIDO sui
# percorsi critici (strumenti, elenco approvato, logs, gettone); il find completo (4-5 minuti) lo fa collaudi-tutti.sh.
for _p in /mnt/linuxulator2/vm/nested-work /mnt/linuxulator2/vm/nested-work/logs /mnt/linuxulator2/vm/nested-work/caldo \
    /mnt/linuxulator2/vm/nested-work/gettone /mnt/linuxulator2/vm/nested-work/collaudo-bin /mnt/linuxulator2/vm/nested-work/collaudo-preambolo.sh \
    /mnt/linuxulator2/vm/nested-work/APPROVATI-sequenza.sha256 $(/usr/bin/awk '$1 !~ /^#/ {print $2}' /mnt/linuxulator2/vm/nested-work/APPROVATI-sequenza.sha256 2>/dev/null); do
	if [ -w "$_p" ]; then echo "STOP: l'utente collaudo puo' scrivere $_p"; exit 2; fi
done
