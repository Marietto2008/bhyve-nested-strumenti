# linux-traccia-vpci.ps1 -- Claude 03/11/2026. Esegue linux-traccia-vpci.sh dentro Debian (WSL, kernel Linux).
& wsl.exe -d Debian -u root -- sh /mnt/c/claude/linux-traccia-vpci.sh 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-File -Encoding utf8 C:\claude\linux-traccia-vpci.txt
& wsl.exe --shutdown
