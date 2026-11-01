# guardia.sh -- Claude 31/10/2026, parere Opus sull'incidente del collaudo, par. 3.3. Guardia COMUNE delle azioni che
# cambiano lo stato dell'host (kldload/kldunload, devctl, kenv in scrittura, sysctl in scrittura, bhyvectl --destroy,
# avvio di VM). Si carica con `. /mnt/linuxulator2/vm/nested-work/caldo/guardia.sh` e si chiama SULLA STESSA RIGA
# dell'azione: `guardia_azione && sudo -n ...` (controllo-azioni.sh lo verifica). Rifiuta:
#   - qualunque variabile *_FINTO nell'ambiente, tranne quella passata come argomento (il collaudo dello strumento
#     stesso, le cui funzioni d'azione sono gia' sostituite);
#   - l'utente `collaudo` (i collaudi non agiscono mai; e comunque non ha sudo).
# Posto per il futuro gettone d'autorizzazione (par. 3.2).
guardia_azione() {
	_ga=$(/usr/bin/env | /usr/bin/sed -n 's/^\([A-Za-z0-9_]*_FINTO\)=.*/\1/p' | /usr/bin/grep -vx "${1:-NESSUNA_AMMESSA}" | /usr/bin/tr '\n' ' ')
	if [ -n "$_ga" ]; then echo "GUARDIA: variabile di collaudo nell'ambiente ($_ga): nessuna azione sull'host" >&2; return 1; fi
	# l'utente collaudo non agisce mai, salvo lo strumento nel SUO modo di prova (variabile ammessa presente: le sue
	# funzioni d'azione sono gia' sostituite dal finto, e collaudo comunque non ha sudo)
	_gv=; [ -n "${1:-}" ] && eval "_gv=\${$1:-}"
	if [ -z "$_gv" ] && [ "$(/usr/bin/id -un)" = collaudo ]; then echo "GUARDIA: utente collaudo: nessuna azione sull'host" >&2; return 1; fi
	return 0
}
