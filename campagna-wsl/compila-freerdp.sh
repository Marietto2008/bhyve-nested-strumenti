#!/bin/sh
# compila-freerdp.sh -- Claude 03/11/2026. FreeRDP-mirror (ramo working) per WSLg su FreeBSD 15.2, opzioni come nel
# Dockerfile di WSLg (solo server, canali gfxredir e rdpapplist). Si esegue nel chroot radice152.
set -eu
pkg install -y icu >/dev/null 2>&1 || true
cd /root/wslg/FreeRDP
cmake -G Ninja -B build2 -DCMAKE_C_FLAGS=-I/usr/local/include -DCMAKE_CXX_FLAGS=-I/usr/local/include -DCMAKE_EXE_LINKER_FLAGS=-L/usr/local/lib -DCMAKE_SHARED_LINKER_FLAGS=-L/usr/local/lib \
	-DCMAKE_INSTALL_PREFIX=/usr/local/wslg -DCMAKE_INSTALL_LIBDIR=/usr/local/wslg/lib -DCMAKE_BUILD_TYPE=Release \
	-DWITH_ICU=ON -DWITH_SERVER=ON -DWITH_CHANNEL_GFXREDIR=ON -DWITH_CHANNEL_RDPAPPLIST=ON \
	-DWITH_CLIENT=OFF -DWITH_CLIENT_COMMON=OFF -DWITH_CLIENT_CHANNELS=OFF -DWITH_CLIENT_INTERFACE=OFF \
	-DWITH_LIBSYSTEMD=OFF -DWITH_WAYLAND=OFF -DWITH_X11=OFF -DWITH_PROXY=OFF -DWITH_SHADOW=OFF -DWITH_SAMPLE=OFF \
	-DWITH_FFMPEG=OFF -DWITH_ALSA=OFF -DWITH_PULSE=OFF -DWITH_OSS=OFF -DWITH_CUPS=OFF -DWITH_PCSC=OFF -DWITH_FUSE=OFF \
	-DCHANNEL_URBDRC=OFF -DWITH_GSTREAMER_1_0=OFF > /root/wslg/freerdp-cmake.log 2>&1 || { tail -30 /root/wslg/freerdp-cmake.log; exit 1; }
ninja -C build2 -j8 > /root/wslg/freerdp-ninja.log 2>&1 || { grep -m20 -B2 -A6 'error:' /root/wslg/freerdp-ninja.log; exit 1; }
ninja -C build2 install > /root/wslg/freerdp-install.log 2>&1
ls /usr/local/wslg/lib | head -20
