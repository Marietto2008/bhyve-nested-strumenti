# vivo-dtrace.ps1 -- Claude 16/11/2026, prova (b) v2: dentro FreeBSD-L2, per ogni CPU, cc_lastscan e cc_firstevent del
# callout (kern_timeout.c) e nextevent/nextcall di timerstate, confrontati con sbinuptime. Sola lettura (dtrace BEGIN).
$o = 'C:\claude\vivo.txt'; "inizio $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Encoding utf8
$c = 'mount; ls /mnt; ls -d /mnt/c/claude 2>&1'
$p = Start-Process -FilePath wsl.exe -ArgumentList "-d FreeBSD -u root -e sh -c `"$c`"" -RedirectStandardOutput C:\claude\vivo-out.txt -RedirectStandardError C:\claude\vivo-err.txt -NoNewWindow -PassThru
if (-not $p.WaitForExit(120000)) { "NON RISPONDE in 120 s" | Out-File $o -Append -Encoding utf8; $p.Kill() }
Get-Content C:\claude\vivo-out.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
Get-Content C:\claude\vivo-err.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
"fine $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Append -Encoding utf8
