# vivo-osserva.ps1 -- Claude 15/11/2026, prova (b): stack di kernel dei thread di claude-lag e timer per CPU in due campioni a 5 s. Non tocca nulla.
$o = 'C:\claude\vivo.txt'; "inizio $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Encoding utf8
$c = 'date; ps -axH -o pid,lwp,state,time,wchan,cpu,etime,command | grep -e claude-lag -e PID; procstat -kk $(pgrep -x claude-lag); procstat -t $(pgrep -x claude-lag); vmstat -i | grep timer; sleep 5; date; vmstat -i | grep timer; ps -axH -o lwp,time,wchan,cpu -p $(pgrep -x claude-lag); sysctl kern.eventtimer.timer kern.eventtimer.periodic kern.timecounter.hardware'
$p = Start-Process -FilePath wsl.exe -ArgumentList "-d FreeBSD -u root -e sh -c `"$c`"" -RedirectStandardOutput C:\claude\vivo-out.txt -NoNewWindow -PassThru
if (-not $p.WaitForExit(45000)) { "NON RISPONDE in 45 s" | Out-File $o -Append -Encoding utf8; $p.Kill() }
Get-Content C:\claude\vivo-out.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
"fine $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Append -Encoding utf8
