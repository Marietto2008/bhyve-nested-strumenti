# vivo-copia-dump.ps1 -- Claude 16/11/2026: copia binaria del dump vivo di L2 (savecore -L) in C:\claude\livecore.0.zst
# (cmd.exe ridirige in binario; PowerShell 5 corromperebbe i byte) e sha256 calcolato dentro L2 per il confronto.
$o = 'C:\claude\vivo.txt'; "inizio $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Encoding utf8
Remove-Item C:\claude\livecore.0.zst -ErrorAction SilentlyContinue
$p = Start-Process -FilePath cmd.exe -ArgumentList '/c wsl.exe -d FreeBSD -u root -e cat /distro/dump-blocco-v2/livecore.0.zst > C:\claude\livecore.0.zst' -NoNewWindow -PassThru
if (-not $p.WaitForExit(300000)) { "COPIA NON FINITA in 300 s" | Out-File $o -Append -Encoding utf8; $p.Kill() }
$q = Start-Process -FilePath wsl.exe -ArgumentList '-d FreeBSD -u root -e sha256 /distro/dump-blocco-v2/livecore.0.zst' -RedirectStandardOutput C:\claude\vivo-out.txt -NoNewWindow -PassThru
$q.WaitForExit(120000) | Out-Null
Get-Content C:\claude\vivo-out.txt -ErrorAction SilentlyContinue | Out-File $o -Append -Encoding utf8
"dimensione su Windows: $((Get-Item C:\claude\livecore.0.zst).Length)" | Out-File $o -Append -Encoding utf8
"fine $((Get-Date).ToString('HH:mm:ss'))" | Out-File $o -Append -Encoding utf8
