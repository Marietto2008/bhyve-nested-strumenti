# Claude 24/10/2026, richiesta dell'utente: sorveglia il PowerShell che esegue i comandi
# WSL (wsl-passo.ps1, attivita' pianificata claude-wsl) e, quando non gira come dovrebbe,
# LO AVVIA, avvisando.
# Il caso reale del 24/10 01:14: un comando nuovo scritto in C:\claude\wsl-args.txt mentre
# claude-wsl era ancora in esecuzione; Windows rifiuta di avviarla di nuovo e niente parte.
# Un comando e' PARTITO quando wsl-passo ha scritto in wsl-log.txt la sua intestazione
# "=== HH:mm:ss wsl <comando>" con quel comando e un'ora non anteriore alla richiesta
# (cosi' un avvio normale, con l'attivita' gia' "in esecuzione", non si scambia per una
# collisione e non viene lanciato due volte).
# Ogni 5 s guarda SOLO la data di wsl-args.txt (costo trascurabile durante le misure);
# il resto solo quando c'e' un comando in sospeso o in corso.
#  - dopo 10 s dalla richiesta: non partito e claude-wsl ancora in esecuzione = collisione:
#    aspetta che finisca, poi avvia claude-wsl (che leggera' il comando nuovo);
#  - non partito entro 90 s con claude-wsl ferma: la avvia; se dopo altri 90 s non e'
#    partito, avvisa e lascia quel comando;
#  - il PowerShell di wsl-passo sparisce senza la riga "codice" (chiuso a mano, ucciso):
#    rilancia lo stesso comando UNA volta (la compilazione riparte da capo: kbuild4.sh fa
#    mrproper); se sparisce di nuovo, avvisa soltanto.
# Ogni azione: UDP all'host (porta 7124, ricevitore claude_winalert) e C:\claude\avvisi.log.
# Avviata al login da un'attivita' pianificata (claude-wsl-guardia), nascosta (wscript +
# wsl-guardia.vbs). Se esiste C:\claude\guardia-pausa resta ferma (parere #40 §9).
param([string]$Host_ = "IP-HOST", [int]$Porta = 7124)
$args_f = "C:\claude\wsl-args.txt"
$log_f = "C:\claude\wsl-log.txt"
$avvisi = "C:\claude\avvisi.log"
$udp = New-Object System.Net.Sockets.UdpClient
function Avvisa([string]$m) {
    $r = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') WSL-GUARDIA $m"
    $r | Out-File -Append -Encoding utf8 $avvisi
    try { $b = [Text.Encoding]::UTF8.GetBytes($r); [void]$udp.Send($b, $b.Length, $Host_, $Porta) } catch { }
}
function Mtime([string]$f) { if (Test-Path $f) { (Get-Item $f).LastWriteTimeUtc } else { [datetime]::MinValue } }
function Ora { (Get-Date).ToUniversalTime() }
function PassoVivo { [bool](Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'wsl-passo\.ps1' }) }
function TaskInCorso { ((schtasks /query /tn claude-wsl /fo csv /nh 2>$null) -join '') -match 'esecuzione|Running' }
function Comando { if (Test-Path $args_f) { (Get-Content $args_f -Raw).Trim() } else { "" } }
function Partito([datetime]$rich) {     # $rich: ora (UTC) dopo la quale deve comparire l'intestazione
    if (-not (Test-Path $log_f)) { return $false }
    $h = Get-Content $log_f | Where-Object { $_ -match '^\W*=== (\d\d:\d\d:\d\d) wsl (.*)$' } | Select-Object -Last 1
    if (-not $h -or $h -notmatch '^\W*=== (\d\d:\d\d:\d\d) wsl (.*)$') { return $false }
    $t = [datetime]::ParseExact($Matches[1], 'HH:mm:ss', $null)
    $r = $rich.ToLocalTime()
    $soglia = [datetime]::ParseExact($r.ToString('HH:mm:ss'), 'HH:mm:ss', $null).AddSeconds(-2)
    return ($Matches[2].Trim() -eq (Comando)) -and ($t -ge $soglia)
}
function Avvia([string]$perche) {
    $o = (schtasks /run /tn claude-wsl 2>&1) -join ' '
    Avvisa "AVVIO claude-wsl ($perche): $o | comando: $(Comando)"
}
$visto = Mtime $args_f
$attesa = $null          # ora (UTC) della richiesta ancora da veder partire
$forzato = $false        # gia' avviata una volta da me per questa richiesta
$coda = $false           # collisione: aspetto che la precedente finisca
$inCorso = $false        # il comando corrente e' partito e wsl-passo era vivo
$rilanciato = [datetime]::MinValue   # richiesta gia' rilanciata dopo una chiusura
$inCorso = PassoVivo     # un comando gia' in corso all'avvio della guardia
Avvisa "avviata (sorveglia $args_f; comando in corso: $inCorso)"
$pausa_f = "C:\claude\guardia-pausa"
# una pausa rimasta da una corsa interrotta non vale dopo un nuovo avvio della guardia
if (Test-Path $pausa_f) { Remove-Item $pausa_f -ErrorAction SilentlyContinue; Avvisa "tolta una pausa rimasta dalla sessione precedente" }
$inPausa = $false
while ($true) {
    Start-Sleep -Seconds 5
    # parere #40 §9: durante le misure lo script crea guardia-pausa: niente controlli
    if (Test-Path $pausa_f) {
        if (-not $inPausa) { $inPausa = $true; Avvisa "in pausa ($pausa_f presente)" }
        continue
    } elseif ($inPausa) {
        $inPausa = $false; $visto = Mtime $args_f; $attesa = $null; $coda = $false; $inCorso = PassoVivo
        Avvisa "ripresa (comando in corso: $inCorso)"
    }
    $m = Mtime $args_f
    if ($m -gt $visto) { $visto = $m; $attesa = $m; $forzato = $false; $coda = $false; $inCorso = $false }
    if ($coda) {
        if (-not (TaskInCorso)) { $coda = $false; $forzato = $true; $attesa = Ora; Avvia "la precedente e' finita" }
        continue
    }
    if ($attesa -ne $null) {
        $dt = ((Ora) - $attesa).TotalSeconds
        if (Partito $attesa) {
            $attesa = $null; $inCorso = $true
        } elseif ($dt -gt 10 -and -not $forzato -and (TaskInCorso) -and -not (Partito $attesa)) {
            $coda = $true
            Avvisa "comando nuovo mentre claude-wsl e' ANCORA in esecuzione col precedente: lo avvio appena finisce. Comando: $(Comando)"
        } elseif ($dt -gt 90 -and -not (TaskInCorso)) {
            if (-not $forzato) {
                $forzato = $true; $attesa = Ora; Avvia "non partito entro 90 s"
            } else {
                Avvisa "il comando NON parte nemmeno dopo l'avvio forzato: lo lascio. Comando: $(Comando)"
                $attesa = $null
            }
        }
        continue
    }
    if ($inCorso -and -not (PassoVivo)) {
        $inCorso = $false
        $ultima = if (Test-Path $log_f) { (Get-Content $log_f -Tail 1) } else { "" }
        if ($ultima -notmatch 'codice') {
            if ($rilanciato -ne $visto) {
                $rilanciato = $visto; $forzato = $true; $attesa = Ora
                Avvia "wsl-passo sparito senza codice d'uscita (ultima riga: $ultima)"
            } else {
                Avvisa "wsl-passo sparito di nuovo senza codice d'uscita: non lo rilancio piu'. Ultima riga: $ultima"
            }
        }
    }
}
