fetch -q -o /tmp/wslg.tar.xz http://IP-HOST:8765/wslg-freebsd.tar.xz && sha256 -q /tmp/wslg.tar.xz && tar -xJf /tmp/wslg.tar.xz -C / && echo weston aggiornato
echo ==== desktop; ls /usr/local/share/applications | grep -i -e foot -e xterm -e xclock; ls -d /usr/local/share/icons/hicolor/*/apps/foot* /usr/local/share/pixmaps/*xterm* 2>&1 | head
mkdir -p /tmp/wslg-runtime; : > /tmp/wslg-runtime/weston.log
wslg-avvia rail > /tmp/wslg-avvia.log 2>&1 & true
sleep 30
env DISPLAY=:0 xclock -geometry 300x300+0+0 > /tmp/xclock.log 2>&1 & true
env DISPLAY=:0 xterm -title FreeBSD-X11 -e sh -c 'uname -a; freebsd-version -ku; echo X11 da FreeBSD in WSLg; sleep 900' > /tmp/xterm.log 2>&1 & true
env XDG_RUNTIME_DIR=/tmp/wslg-runtime WAYLAND_DISPLAY=wayland-0 foot --title=FreeBSD-Wayland sh -c 'uname -a; echo Wayland da FreeBSD in WSLg; sleep 900' > /tmp/foot.log 2>&1 & true
sleep 60
echo DISTRO=$WSL_DISTRO_NAME; echo ==== app list; grep -e rdpapplist -e Assertion -e appProvider -e 'app_list_monitor_thread: monitor' -e 'entry 0x' -e 'file created' -e 'icon' -e 'ClientGetAppidReq: pid' /tmp/wslg-runtime/weston.log | head -40
