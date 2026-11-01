# Claude 20/10/2026: esegue un comando wsl nella sessione interattiva e ne registra output e codice.
$Args1 = (Get-Content C:\claude\wsl-args.txt -Raw).Trim()
$log = "C:\claude\wsl-log.txt"
"=== $(Get-Date -Format HH:mm:ss) wsl $Args1" | Out-File -Append -Encoding utf8 $log
$p = Start-Process -FilePath "$env:SystemRoot\System32\wsl.exe" -ArgumentList $Args1 -NoNewWindow -Wait -PassThru `
     -RedirectStandardOutput C:\claude\o.txt -RedirectStandardError C:\claude\e.txt
$o = [IO.File]::ReadAllText("C:\claude\o.txt", [Text.Encoding]::Unicode) + [IO.File]::ReadAllText("C:\claude\e.txt", [Text.Encoding]::Unicode)
$o | Out-File -Append -Encoding utf8 $log
"=== $(Get-Date -Format HH:mm:ss) codice $($p.ExitCode)" | Out-File -Append -Encoding utf8 $log
