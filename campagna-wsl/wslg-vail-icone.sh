echo ==== VAIL kernel; uname -v; ls -l /dev/wslgshm; dmesg | grep -i -e wslgshm -e vtfs -e 'shared memory' | tail -5
echo ==== ambiente; echo OB=$WSL2_SHARED_MEMORY_OB_DIRECTORY VM=$WSL_VM_ID
fetch -q -o /tmp/wslg.tar.xz http://IP-HOST:8765/wslg-freebsd.tar.xz && sha256 -q /tmp/wslg.tar.xz && tar -xJf /tmp/wslg.tar.xz -C / && echo weston aggiornato
strings /usr/local/wslg/lib/libweston-9/rdp-backend.so | grep -c 'window offset'
mkdir -p /tmp/wslg-runtime; : > /tmp/wslg-runtime/weston.log
wslg-avvia rail > /tmp/wslg-avvia.log 2>&1 & true
sleep 30
env DISPLAY=:0 xclock -geometry 300x300+0+0 > /tmp/xclock.log 2>&1 & true
env DISPLAY=:0 xterm -title FreeBSD-X11 -e sh -c 'uname -a; freebsd-version -ku; echo X11 da FreeBSD in WSLg; sleep 900' > /tmp/xterm.log 2>&1 & true
env XDG_RUNTIME_DIR=/tmp/wslg-runtime WAYLAND_DISPLAY=wayland-0 foot --title=FreeBSD-Wayland sh -c 'uname -a; echo Wayland da FreeBSD in WSLg; sleep 900' > /tmp/foot.log 2>&1 & true
sleep 60
echo ==== icone; grep -i -e 'readlink failed' -e 'kern.proc.pathname' -e 'image_path' -e 'ClientGetAppidReq: pid' /tmp/wslg-runtime/weston.log | head -20
echo ==== dmesg; dmesg | grep -i wslgshm | tail -3; sysctl hw.wslgshm
