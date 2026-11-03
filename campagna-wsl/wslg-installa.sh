pkg install -y wayland libxkbcommon xkeyboard-config pixman cairo pango png libjpeg-turbo webp glib libinput libevdev libdrm icu libepoll-shim libffi dejavu libXcursor xcursor-themes 2>&1 | tail -2
fetch -q -o /tmp/wslg.tar.xz http://IP-HOST:8765/wslg-freebsd.tar.xz
sha256 -q /tmp/wslg.tar.xz
tar -xJf /tmp/wslg.tar.xz -C /
ls /usr/local/wslg/bin
env LD_LIBRARY_PATH=/usr/local/wslg/lib ldd /usr/local/wslg/bin/weston /usr/local/wslg/lib/libweston-9/rdp-backend.so /usr/local/wslg/lib/weston/desktop-shell.so | grep -c 'not found'
df -h / | tail -1
