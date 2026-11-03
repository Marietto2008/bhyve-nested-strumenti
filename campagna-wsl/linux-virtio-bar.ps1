# linux-virtio-bar.ps1 -- Claude 03/11/2026. Esegue linux-virtio-bar.sh dentro Debian (WSL, kernel Linux).
& wsl.exe -d Debian -u root -- sh /mnt/c/claude/linux-virtio-bar.sh 2>&1 | ForEach-Object { "$_" -replace "`0", "" } | Out-File -Encoding utf8 C:\claude\linux-virtio-bar.txt
& wsl.exe --shutdown
