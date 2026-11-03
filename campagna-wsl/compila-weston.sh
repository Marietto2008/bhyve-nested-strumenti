#!/bin/sh
# compila-weston.sh -- Claude 03/11/2026. rdpapplist (repo wslg) e weston-mirror (ramo working) per WSLg su FreeBSD
# 15.2, opzioni come nel Dockerfile di WSLg; dipende da FreeRDP-mirror in /usr/local/wslg. Nel chroot radice152.
set -eu
export PKG_CONFIG_PATH=/usr/local/wslg/lib/pkgconfig:/usr/local/wslg/share/pkgconfig:/usr/local/libdata/pkgconfig
export CFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib -lepoll-shim"
cd /root/wslg/rdpapplist
[ -d build ] || meson setup --prefix=/usr/local/wslg build > /root/wslg/rdpapplist-meson.log 2>&1 || { tail -20 /root/wslg/rdpapplist-meson.log; exit 1; }
ninja -C build install > /root/wslg/rdpapplist-ninja.log 2>&1 || { grep -m20 -B2 -A6 'error' /root/wslg/rdpapplist-ninja.log; exit 1; }
cd /root/wslg/weston
[ -f build4/build.ninja ] || meson setup --prefix=/usr/local/wslg build4 --buildtype=release \
	-Dbackend-default=rdp -Dlauncher-logind=false -Dweston-launch=false -Dbackend-drm=false -Dbackend-drm-screencast-vaapi=false -Dbackend-headless=false \
	-Dbackend-wayland=false -Dbackend-x11=false -Dbackend-fbdev=false -Dcolor-management-colord=false \
	-Dscreenshare=false -Dsystemd=false -Dwslgd=true -Dremoting=false -Dpipewire=false -Dshell-fullscreen=false \
	-Dcolor-management-lcms=false -Dshell-ivi=false -Dshell-kiosk=false -Ddemo-clients=false -Dsimple-clients=[] \
	-Dtools=[] -Dresize-pool=false -Dwcap-decode=false -Dtest-junit-xml=false \
	> /root/wslg/weston-meson.log 2>&1 || { tail -30 /root/wslg/weston-meson.log; exit 1; }
ninja -C build4 -j8 > /root/wslg/weston-ninja.log 2>&1 || { grep -m30 -B2 -A8 'error' /root/wslg/weston-ninja.log; exit 1; }
ninja -C build4 install > /root/wslg/weston-install.log 2>&1
ls /usr/local/wslg/bin /usr/local/wslg/lib/weston /usr/local/wslg/lib/libweston-9 2>/dev/null
