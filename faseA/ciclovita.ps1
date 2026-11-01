# Claude 21/10/2026 fase A (parere #23): ciclo di vita della partizione WSL2.
# N volte: wsl --shutdown (distrugge la VM di utilita'), poi un comando in Debian
# (la ricrea). Registra durata, codice e uscita di ogni ciclo.
param([int]$N = 20)
$log = "C:\claude\faseA\ciclovita.log"
"=== $(Get-Date -Format s) inizio, $N cicli" | Out-File -Encoding utf8 $log
$ok = 0
for ($i = 1; $i -le $N; $i++) {
  $t0 = Get-Date
  & "$env:SystemRoot\System32\wsl.exe" --shutdown
  $c1 = $LASTEXITCODE
  $out = & "$env:SystemRoot\System32\wsl.exe" -d Debian -u root -- sh -c "cat /proc/sys/kernel/random/boot_id; cut -d' ' -f1 /proc/uptime"
  $c2 = $LASTEXITCODE
  $dt = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $txt = ($out -join ' ')
  if ($c1 -eq 0 -and $c2 -eq 0 -and $txt -match '^[0-9a-f-]{36} ') { $ok++ }
  "ciclo $i shutdown=$c1 avvio=$c2 durata=${dt}s uscita=$txt" | Out-File -Append -Encoding utf8 $log
}
"=== $(Get-Date -Format s) FINE ok=$ok/$N" | Out-File -Append -Encoding utf8 $log
