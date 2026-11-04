mkdir -p /tmp/wslg-runtime; : > /tmp/wslg-runtime/weston.log
wslg-avvia rail > /tmp/wslg-avvia.log 2>&1 & true
sleep 30
env DISPLAY=:0 xterm -title FreeBSD-X11 -e sh -c 'uname -a; freebsd-version -ku; echo X11 da FreeBSD in WSLg; sleep 900' > /tmp/xterm.log 2>&1 & true
env DISPLAY=:0 xclock > /tmp/xclock.log 2>&1 & true
env XDG_RUNTIME_DIR=/tmp/wslg-runtime WAYLAND_DISPLAY=wayland-0 foot --title=FreeBSD-Wayland sh -c 'uname -a; echo Wayland da FreeBSD in WSLg; sleep 900' > /tmp/foot.log 2>&1 & true
sleep 200
cat /tmp/wslg-avvia.log; tail -3 /tmp/xterm.log /tmp/xclock.log /tmp/foot.log; tail -90 /tmp/wslg-runtime/weston.log
