echo ==== VAIL carico; uname -v; mkdir -p /tmp/wslg-runtime; : > /tmp/wslg-runtime/weston.log
wslg-avvia rail > /tmp/wslg-avvia.log 2>&1 & true
sleep 30
env DISPLAY=:0 xterm -title FreeBSD-X11 -e sh -c 'echo X11 da FreeBSD in WSLg, prova di carico; sleep 900' > /tmp/xterm.log 2>&1 & true
env XDG_RUNTIME_DIR=/tmp/wslg-runtime WAYLAND_DISPLAY=wayland-0 foot --title=FreeBSD-Wayland sh -c 'echo Wayland da FreeBSD in WSLg; sleep 900' > /tmp/foot.log 2>&1 & true
sleep 15
echo ==== prima; sysctl hw.wslgshm
i=0; while [ $i -lt 60 ]; do w=$((200 + (i * 37) % 1000)); h=$((150 + (i * 53) % 650)); env DISPLAY=:0 xclock -update 1 -geometry ${w}x${h}+$((i * 13 % 300))+$((i * 7 % 200)) > /dev/null 2>&1 & p=$!; sleep 2; kill $p; i=$((i + 1)); done
sleep 10
echo ==== dopo 60 finestre; sysctl hw.wslgshm
pkill xterm; pkill foot; sleep 10
echo ==== dopo la chiusura di tutte; sysctl hw.wslgshm
echo ==== dmesg wslgshm; dmesg | grep -i wslgshm | tail -20
echo ==== weston errori; grep -i -e failed -e error -e 'COPY MODE' /tmp/wslg-runtime/weston.log | grep -v -i 'gcc client data' | head -30
