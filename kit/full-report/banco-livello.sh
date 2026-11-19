#!/bin/sh
# banco-livello.sh -- Claude 18/11/2026. La stessa batteria a ogni livello (L0 host, L1, L2), FreeBSD o Linux.
# Uso: banco-livello.sh [cartella con conf]. Variabili: LIVELLO (etichetta), SEC (secondi per prova del banco, 5), DISCO (cartella scrivibile per la prova del
# disco; vuota = salta), HOST (indirizzo dell'host per rete e binario; vuoto = salta la rete), BIN (claude-banco;
# se manca e HOST c'e', lo scarica da http://HOST:8765/), RETE_MB (MB per verso, 1024).
# Con un argomento (la cartella di collaudo, come vuole la regola: sudo -n -u collaudo ... _ <script> <cartella>)
# la configurazione si legge da dati-banco/<nome della cartella>.conf (righe VAR=valore): sudo azzera l'ambiente.
if [ -n "${1:-}" ]; then
	c=/mnt/linuxulator2/vm/confronto-kvm-bhyve/dati-banco/$(basename "$1").conf
	[ -f "$c" ] && . "$c"
fi
LIVELLO=${LIVELLO:-?}; SEC=${SEC:-5}; RETE_MB=${RETE_MB:-1024}
echo "LIVELLO $LIVELLO $(uname -sr) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
uptime
if [ -z "${BIN:-}" ] || [ ! -x "$BIN" ]; then
	BIN=/tmp/claude-banco
	if [ "$(uname -s)" = Linux ]; then
		# su Linux il sorgente, compilato sul posto
		wget -q -O /tmp/claude-banco.c "http://$HOST:8765/claude-banco.c" ||
		    curl -s -o /tmp/claude-banco.c "http://$HOST:8765/claude-banco.c"
		cc -O2 -pthread -o "$BIN" /tmp/claude-banco.c || { echo "BANCO errore: compilazione"; exit 1; }
	else
		fetch -q -o "$BIN" "http://$HOST:8765/claude-banco" || { echo "BANCO errore: scaricamento"; exit 1; }
		chmod 755 "$BIN"
	fi
fi
"$BIN" "$SEC"
# disco: 1 GB scritto con fsync finale, poi lo stesso file riportato a zero byte (niente rm)
if [ -n "${DISCO:-}" ] && [ -d "$DISCO" ]; then
	f="$DISCO/claude-banco-disco.bin"
	r=$(dd if=/dev/zero of="$f" bs=1048576 count=1024 conv=fsync 2>&1 | tail -1)
	echo "BANCO disco_scrittura $r"
	[ -f "$f" ] && : > "$f"
fi
# rete verso l'host: scarico da HOST:8766 (1 GB, poi il server chiude) e mando RETE_MB a HOST:8767 (nc -> /dev/null)
if [ -n "${HOST:-}" ]; then
	# il server di 8766 manda 1 GB e chiude; ogni nc ha un tetto di 120 s (una rete ferma non blocca la batteria)
	# senza nc (Debian minima) si usa il /dev/tcp di bash
	if command -v nc >/dev/null; then
		# -d e stdin da /dev/null: se no nc aspetta anche la fine dello stdin (un terminale) e arriva al timeout (18/11)
		scarica() { timeout 120 nc -d "$HOST" 8766 < /dev/null; }
		manda() { timeout 120 nc -N "$HOST" 8767; }
	else
		scarica() { timeout 120 bash -c "cat < /dev/tcp/$HOST/8766"; }
		manda() { timeout 120 bash -c "cat > /dev/tcp/$HOST/8767"; }
	fi
	r=$(scarica 2>/dev/null | dd of=/dev/null bs=1048576 2>&1 | tail -1)
	echo "BANCO rete_scarico $r"
	r=$( { dd if=/dev/zero bs=1048576 count="$RETE_MB" | manda; } 2>&1 | grep -E 'bytes|byte|copied|copiat' | tail -1)
	echo "BANCO rete_invio $r"
fi
echo "LIVELLO $LIVELLO fine $(date -u +%H:%M:%SZ)"
