# Claude 20/10/2026 fase A (parere #23): orologio di Windows (root di Hyper-V) sotto carico.
# Ogni 10 ms: Stopwatch (QPC) e DateTime.UtcNow. Salti all'indietro, buchi > 200 ms,
# deriva wall-QPC. Riepilogo ogni 60 s. Argomento: secondi.
param([int]$Sec = 14400)
$log = "C:\claude\faseA\clockmon-win.log"
$sw = [Diagnostics.Stopwatch]::StartNew(); $w0 = [DateTime]::UtcNow
$last = 0.0; $gmax = 0.0; $gtot = 0.0; $back = 0; $holes = 0; $rep = 0.0; $n = 0
while ($sw.Elapsed.TotalSeconds -lt $Sec) {
  Start-Sleep -Milliseconds 10
  $m = $sw.Elapsed.TotalMilliseconds; $g = $m - $last; $n++
  if ($g -lt 0) { $back++; "!!! QPC all'indietro $g ms" | Out-File -Append -Encoding utf8 $log }
  if ($g -gt $gmax) { $gmax = $g }
  if ($g -gt $gtot) { $gtot = $g }
  if ($g -gt 200) { $holes++; "buco di $([int]$g) ms a $([int]($m/1000)) s" | Out-File -Append -Encoding utf8 $log }
  $last = $m
  if ($m - $rep -ge 60000) {
    $d = ([DateTime]::UtcNow - $w0).TotalMilliseconds - $m
    "t=$([int]($m/1000))s campioni=$n gapmax_min=$([math]::Round($gmax,1))ms gapmax=$([math]::Round($gtot,1))ms buchi=$holes indietro=$back deriva(wall-qpc)=$([math]::Round($d,3))ms" | Out-File -Append -Encoding utf8 $log
    $gmax = 0; $rep = $m
  }
}
"FINE" | Out-File -Append -Encoding utf8 $log
