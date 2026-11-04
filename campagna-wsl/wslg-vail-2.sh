echo ==== VAIL kernel; uname -v; ls -l /dev/wslgshm; dmesg | grep -i -e wslgshm -e vtfs -e 'shared memory' | tail -5
echo ==== ambiente; echo OB=$WSL2_SHARED_MEMORY_OB_DIRECTORY VM=$WSL_VM_ID
mkdir -p /tmp/wslg-runtime; : > /tmp/wslg-runtime/weston.log
wslg-avvia rail > /tmp/wslg-avvia.log 2>&1 & true
sleep 30
env DISPLAY=:0 xclock -geometry 300x300+0+0 > /tmp/xclock.log 2>&1 & true
env DISPLAY=:0 xterm -title FreeBSD-X11 -e sh -c 'uname -a; freebsd-version -ku; echo X11 da FreeBSD in WSLg; sleep 900' > /tmp/xterm.log 2>&1 & true
env XDG_RUNTIME_DIR=/tmp/wslg-runtime WAYLAND_DISPLAY=wayland-0 foot --title=FreeBSD-Wayland sh -c 'uname -a; echo Wayland da FreeBSD in WSLg; sleep 900' > /tmp/foot.log 2>&1 & true
sleep 300
echo ==== dmesg wslgshm; dmesg | grep -i -e wslgshm -e vtfs | tail -30
echo ==== wslg-avvia.log; cat /tmp/wslg-avvia.log
echo ==== weston VAIL; grep -i -e failed -e error -e 'surface.*shared' -e gfxredir -e shared_memory -e 'shared memory' -e SHARED_MEMORY -e 'COPY MODE' -e 'window offset' /tmp/wslg-runtime/weston.log | head -40
echo ==== weston coda; tail -40 /tmp/wslg-runtime/weston.log
