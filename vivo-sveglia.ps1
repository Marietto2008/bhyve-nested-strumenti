# vivo-sveglia.ps1 -- Claude 15/11/2026, prova (b): timer di CPU 3 e thread di claude-lag prima e dopo un cpuset -l 3 /usr/bin/true (lavoro su CPU 3). CAMBIA il risultato: solo dopo la lettura di vivo-osserva.
$o = 'C:\claude\vivo.txt'; "inizio $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Encoding utf8
$c = 'date; vmstat -i | grep cpu3:timer; ps -H -o lwp,time,wchan,cpu -p $(pgrep -x claude-lag); cpuset -l 3 /usr/bin/true; sleep 3; date; vmstat -i | grep cpu3:timer; ps -H -o lwp,time,wchan,cpu -p $(pgrep -x claude-lag); pgrep -x claude-lag; echo FINE-ELENCO'
$p = Start-Process -FilePath wsl.exe -ArgumentList "-d FreeBSD -u root -e sh -c `"$c`"" -RedirectStandardOutput C:\claude\vivo-out.txt -NoNewWindow -PassThru
if (-not $p.WaitForExit(45000)) { "NON RISPONDE in 45 s" | Out-File $o -Append -Encoding utf8; $p.Kill() }
Get-Content C:\claude\vivo-out.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
"fine $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Append -Encoding utf8
