#!/bin/sh
# Claude: wslr.sh "<argomenti wsl>" [attesa_s] -- esegue wsl nella sessione console di marietto sulla VM Windows
w() { sshpass -f /home/marietto/.config/claude-wsl2/password-windows ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o LogLevel=ERROR marietto@win11 "$@" 2>&1 | LC_ALL=C tr -d '\000' | iconv -f CP850 -t UTF-8 2>/dev/null; }
w "echo $1> C:\\claude\\wsl-args.txt & del C:\\claude\\wsl-log.txt 2>nul & schtasks /create /tn claude-wsl /tr \"powershell -NoProfile -ExecutionPolicy Bypass -File C:\\claude\\wsl-passo.ps1\" /sc once /st 00:00 /sd 01/01/2030 /ru marietto /it /rl highest /f >nul & schtasks /run /tn claude-wsl >nul"
sleep ${2:-15}
w "type C:\\claude\\wsl-log.txt"
