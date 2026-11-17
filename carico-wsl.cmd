@echo off
rem claude 15/11/2026: carico in WSL per reset-l2.sh (vCPU in L2 al system_reset)
wsl.exe -e sh -c "for i in 1 2 3 4; do (while :; do :; done) & done; sleep 600"
