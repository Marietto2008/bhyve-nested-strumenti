# vivo-d.ps1 -- Claude 16/11/2026: esegue in L2 C:\claude\prova.d (dtrace -s /dev/stdin).
# callout (kern_timeout.c) e nextevent/nextcall di timerstate, confrontati con sbinuptime. Sola lettura (dtrace BEGIN).
$o = 'C:\claude\vivo.txt'; "inizio $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Encoding utf8
$c = 'kldstat -q -m dtrace || kldload dtraceall; dtrace -s /dev/stdin 2>&1; date; ps -axH -o lwp,pri,wchan,cpu,time,comm -p $(pgrep -x claude-lag)'
$p = Start-Process -FilePath wsl.exe -ArgumentList "-d FreeBSD -u root -e sh -c `"$c`"" -RedirectStandardInput C:\claude\prova.d -RedirectStandardOutput C:\claude\vivo-out.txt -RedirectStandardError C:\claude\vivo-err.txt -NoNewWindow -PassThru
if (-not $p.WaitForExit(120000)) { "NON RISPONDE in 120 s" | Out-File $o -Append -Encoding utf8; $p.Kill() }
Get-Content C:\claude\vivo-out.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
Get-Content C:\claude\vivo-err.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
"fine $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Append -Encoding utf8
