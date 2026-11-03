df -h / | tail -1
pkg install -y librsvg2-rust xwayland xterm xclock 2>&1 | tail -2
env LD_LIBRARY_PATH=/usr/local/wslg/lib ldd /usr/local/wslg/lib/weston/rdprail-shell.so /usr/local/wslg/lib/libweston-9/xwayland.so /usr/local/bin/Xwayland | grep -c "not found"
df -h / | tail -1
