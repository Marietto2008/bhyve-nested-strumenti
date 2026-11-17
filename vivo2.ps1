# vivo2.ps1 -- Claude 12/11/2026: claude-lag e' ancora vivo nell'L2? thread, tempi, timer per CPU. Limite 45 s.
$o = 'C:\claude\vivo.txt'; "inizio $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Encoding utf8
$c = 'date; uptime; ps -axH -o pid,lwp,state,time,wchan,cpu,etime,command | grep -e claude-lag -e PID; vmstat -i | grep timer'
$p = Start-Process -FilePath wsl.exe -ArgumentList "-d FreeBSD -u root -e sh -c `"$c`"" -RedirectStandardOutput C:\claude\vivo-out.txt -NoNewWindow -PassThru
if (-not $p.WaitForExit(45000)) { "NON RISPONDE in 45 s" | Out-File $o -Append -Encoding utf8; $p.Kill() }
Get-Content C:\claude\vivo-out.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
"fine $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Append -Encoding utf8
