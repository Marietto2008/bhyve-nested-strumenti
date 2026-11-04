fetch -q -o /usr/local/sbin/claude-desktop http://IP-HOST:8765/claude-desktop-freebsd; grep -c xdm.pid /usr/local/sbin/claude-desktop; pkill -x xdm; pkill -x Xephyr; true
